class WorkSession < ApplicationRecord
  # ============================================================
  # RELATIONS
  # ============================================================
  belongs_to :contract
  has_many :kilometer_logs, dependent: :destroy

  # ============================================================
  # VALIDATIONS
  # ============================================================
  validates :date, :start_time, :end_time, presence: { message: 'Ce champ est requis' }
  validate  :end_after_start
  validates :hourly_rate, numericality: { greater_than: 0 }
  validate :no_overlap_with_existing_sessions

  # ============================================================
  # ENUM
  # ============================================================
  enum :status, { pending: 0, accepted: 1, declined: 2 }

  # ============================================================
  # SCOPES - pour le planning
  # ============================================================
  scope :for_month, ->(year, month) {
    where(date: Date.new(year, month).all_month)
      .order(:date, :start_time)
  }

  scope :for_year, ->(year) {
    where(date: Date.new(year).all_year)
  }

  scope :upcoming, -> {
    where('date >= ?', Date.today).order(:date)
  }

  scope :past, -> {
    where('date < ?', Date.today).order(date: :desc)
  }

  scope :for_user, ->(user) {
    joins(:contract).where(contracts: { user_id: user.id })
  }

  scope :search, ->(query) {
    return all if query.blank?

    where(
      'company ILIKE :q OR store ILIKE :q OR date::text ILIKE :q',
      q: "%#{query}%"
    )
  }

  scope :current_month, -> {
    where(date: Date.current.beginning_of_month..Date.current.end_of_month)
  }

  # ============================================================
  # CLASSE METHOD
  # ============================================================
  def self.create_from_proposal(proposal)
    contract = proposal.merch.contracts
                       .where(agency: proposal.agency)
                       .order(created_at: :desc)
                       .first

    return unless contract

    WorkSession.create!(
      contract: contract,
      date: proposal.date,
      start_time: proposal.start_time,
      end_time: proposal.end_time,
      hourly_rate: proposal.hourly_rate,
      effective_km: proposal.effective_km || 0.0,
      store: proposal.store_name,
      company: proposal.company,
      recommended: false,
      status: :accepted
    )
  end

  # ============================================================
  # CONSTANTES
  # ============================================================
  NIGHT_START = 21 # 21h
  NIGHT_END   = 6  # 6h

  # ============================================================
  # CALLBACKS : recalcul complet avant sauvegarde
  # ============================================================
  before_validation :fix_timestamps_with_correct_date
  before_validation :ensure_end_time_is_on_correct_day
  before_validation :compute_duration
  before_validation :compute_night_minutes
  before_validation :compute_effective_km

  # ============================================================
  # VALIDATION LOGIQUE
  # ============================================================
  def end_after_start
    return if start_time.blank? || end_time.blank?
    return if end_time > start_time

    errors.add(:end_time, "doit être après l'heure de début")
  end

  # ============================================================
  # Ce callback s'assure que start_time et end_time ont la date correcte
  # ============================================================
  def fix_timestamps_with_correct_date
    return unless date.present?

    if start_time.present? && start_time_changed?
      self.start_time = Time.zone.parse("#{date} #{start_time.strftime('%H:%M:%S')}")
    end

    if end_time.present? && end_time_changed?
      self.end_time = Time.zone.parse("#{date} #{end_time.strftime('%H:%M:%S')}")
    end
  end

  # ============================================================
  # GESTION DES MISSIONS PASSANT MINUIT
  # ============================================================
  def ensure_end_time_is_on_correct_day
    return if start_time.blank? || end_time.blank?
    self.end_time += 1.day if end_time <= start_time
  end

  # ============================================================
  # CALCUL DUREE
  # ============================================================
  def compute_duration
    return if start_time.blank? || end_time.blank?

    total = ((end_time - start_time) / 60).to_i
    self.duration_minutes = total
  end

  # ============================================================
  # CALCUL HEURES DE NUIT
  # ============================================================
  def compute_night_minutes
    return if start_time.blank? || end_time.blank?

    minutes = 0
    current = start_time

    while current < end_time
      minutes += 1 if current.hour >= NIGHT_START || current.hour < NIGHT_END
      current += 1.minute
    end

    self.night_minutes = minutes
  end

  # ============================================================
  # KM EFFECTIFS
  # ============================================================
  def compute_effective_km
    if km_custom.present?
      self.effective_km = km_custom.to_f
      return
    end

    api_km = kilometer_logs.sum(:distance).to_f
    if api_km.positive?
      self.effective_km = api_km
      return
    end

    self.effective_km = 0.0
  end

  # ============================================================
  # CALCUL BRUT
  # ============================================================
  def brut
    return 0 if duration_minutes.zero?

    day_pay + night_pay
  end

  # ============================================================
  # TOTAL REMUNERATION (Interne / Admin)
  # ============================================================
  def total_payment
    base_brut = brut
    amount_ifm = contract.ifm(base_brut)
    # CP calculés sur (Brut + IFM)
    amount_cp  = contract.cp(base_brut + amount_ifm)

    base_brut + amount_ifm + amount_cp + km_payment_final
  end

  def km_payment_final
    contract.km_payment(effective_km.to_f, recommended: recommended)
  end

  # ============================================================
  # NET & NET TOTAL (Public / Merch)
  # ============================================================
  def net
    (brut * (1 - 0.22)).round(2)
  end

  def amount_ifm
    contract.ifm(brut).round(2)
  end

  def amount_cp
    # C'est ici que se fait le calcul corrigé : CP sur (Brut + IFM)
    base = brut + amount_ifm
    contract.cp(base).round(2)
  end

  def net_total
    current_brut = brut

    # 1. Calcul de l'IFM sur le Brut
    amount_ifm = contract.ifm(current_brut).round(2)

    # 2. CORRECTION : Calcul des CP sur (Brut + IFM)
    amount_cp  = contract.cp(current_brut + amount_ifm).round(2)

    amount_km  = contract.km_payment(effective_km).round(2)

    net_ifm = (amount_ifm * 0.78).round(2)
    net_cp  = (amount_cp  * 0.78).round(2)

    (net.round(2) + net_ifm + net_cp + amount_km).round(2)
  end

  # ============================================================
  # MÉTHODES PRIVÉES
  # ============================================================
  private

  # ============================================================
  # VALIDATION : Pas de chevauchement entre sessions
  # ============================================================
  def no_overlap_with_existing_sessions
    return unless contract.present? && date.present? && start_time.present? && end_time.present?

    user_id = contract.user_id

    new_start_dt = DateTime.new(date.year, date.month, date.day, start_time.hour, start_time.min, start_time.sec)
    new_end_dt = DateTime.new(date.year, date.month, date.day, end_time.hour, end_time.min, end_time.sec)

    new_end_dt += 1.day if end_time <= start_time

    date_range = (date - 1.day)..(date + 1.day)

    existing_sessions = WorkSession
      .joins(:contract)
      .where(contracts: { user_id: user_id })
      .where(date: date_range)
      .where.not(id: id)

    has_overlap = existing_sessions.any? do |session|
      existing_start = DateTime.new(
        session.date.year,
        session.date.month,
        session.date.day,
        session.start_time.hour,
        session.start_time.min,
        session.start_time.sec
      )

      existing_end = DateTime.new(
        session.date.year,
        session.date.month,
        session.date.day,
        session.end_time.hour,
        session.end_time.min,
        session.end_time.sec
      )

      existing_end += 1.day if session.end_time <= session.start_time

      existing_start < new_end_dt && existing_end > new_start_dt
    end

    if has_overlap
      errors.add(:base, 'Cette mission chevauche une autre mission déjà enregistrée pour vous. Vérifiez votre planning.')
    end
  end

  def hours_day
    ((duration_minutes - night_minutes) / 60.0).round(2)
  end

  def hours_night
    (night_minutes / 60.0).round(2)
  end

  def day_pay
    hours_day * hourly_rate
  end

  def night_hourly_rate
    hourly_rate * (1 + contract.night_rate)
  end

  def night_pay
    hours_night * night_hourly_rate
  end
end
