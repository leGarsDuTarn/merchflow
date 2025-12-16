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
  # ACCESSEURS DE MONTANTS (Utilisés par Vue + Calculs)
  # ============================================================

  # IFM Brut
  def amount_ifm
    contract.ifm(brut).round(2)
  end

  # CP Brut (Sur Base + IFM)
  def amount_cp
    base = brut + amount_ifm
    contract.cp(base).round(2)
  end

  # Montant KM Final (Gère le recommandé/plafond)
  def km_payment_final
    contract.km_payment(effective_km.to_f, recommended: recommended)
  end

  # ============================================================
  # NET & NET TOTAL (LE COEUR DU CALCUL)
  # ============================================================

  # Net du salaire de base uniquement
  def net
    (brut * 0.78).round(2)
  end

  # Net Total ESTIMÉ (Salaire Net + IFM Net + CP Net + Indemnités KM)
  # C'est cette méthode qui corrige ton dashboard.
  def net_total
    # 1. On récupère les valeurs brutes via nos méthodes
    val_brut = brut
    val_ifm  = amount_ifm
    val_cp   = amount_cp

    # 2. On récupère le montant KM (Non soumis à cotisations)
    val_km   = km_payment_final

    # 3. Calcul des Nets (Déduction de 22% de charges)
    net_salary = (val_brut * 0.78).round(2)
    net_ifm    = (val_ifm  * 0.78).round(2)
    net_cp     = (val_cp   * 0.78).round(2)

    # 4. Somme finale (Tout le net + les KM entiers)
    (net_salary + net_ifm + net_cp + val_km).round(2)
  end

  # ============================================================
  # TOTAL REMUNERATION (Brut Global + KM) - Souvent pour Admin
  # ============================================================
  def total_payment
    brut + amount_ifm + amount_cp + km_payment_final
  end

  # ============================================================
  # MÉTHODES PRIVÉES
  # ============================================================
  private

  # ============================================================
  # VALIDATION : Pas de chevauchement (VERSION ROBUSTE TIMEZONE)
  # ============================================================
  def no_overlap_with_existing_sessions
    return unless contract.present? && date.present? && start_time.present? && end_time.present?

    # Utilisation de Time.zone.parse pour éviter les erreurs UTC/Local
    new_start_dt = Time.zone.parse("#{date} #{start_time.strftime('%H:%M:%S')}")
    new_end_dt   = Time.zone.parse("#{date} #{end_time.strftime('%H:%M:%S')}")

    new_end_dt += 1.day if new_end_dt <= new_start_dt

    date_range = (date - 1.day)..(date + 1.day)

    existing_sessions = WorkSession
      .joins(:contract)
      .where(contracts: { user_id: contract.user_id })
      .where(date: date_range)
      .where.not(id: id)

    has_overlap = existing_sessions.any? do |session|
      existing_start = session.start_time
      existing_end   = session.end_time

      # Logique de chevauchement : (Debut A < Fin B) ET (Fin A > Debut B)
      new_start_dt < existing_end && new_end_dt > existing_start
    end

    if has_overlap
      errors.add(:base, 'Cette mission chevauche une autre mission déjà enregistrée.')
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
