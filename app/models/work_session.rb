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
  validate  :no_overlap_with_existing_sessions
  validate  :validate_break_consistency # Nouvelle validation pour la coupure

  # ============================================================
  # ENUM
  # ============================================================
  enum :status, { pending: 0, accepted: 1, declined: 2 }

  # ============================================================
  # SCOPES
  # ============================================================
  scope :for_month, ->(year, month) {
    where(date: Date.new(year, month).all_month).order(:date, :start_time)
  }
  scope :for_year, ->(year) { where(date: Date.new(year).all_year) }
  scope :upcoming, -> { where('date >= ?', Date.today).order(:date) }
  scope :past, -> { where('date < ?', Date.today).order(date: :desc) }
  scope :for_user, ->(user) { joins(:contract).where(contracts: { user_id: user.id }) }
  scope :search, ->(query) {
    return all if query.blank?
    where('company ILIKE :q OR store ILIKE :q OR date::text ILIKE :q', q: "%#{query}%")
  }
  scope :current_month, -> { where(date: Date.current.beginning_of_month..Date.current.end_of_month) }

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
  # MÉTHODES DE CALCUL DE TEMPS (MODIFIÉES POUR LA COUPURE)
  # ============================================================

  def has_break?
    break_start_time.present? && break_end_time.present?
  end

  # Vérifie si un instant donné est pendant la pause
  def in_break?(time)
    return false unless has_break?
    time >= break_start_time && time < break_end_time
  end

  def compute_duration
    return if start_time.blank? || end_time.blank?

    # On calcule l'enveloppe totale en minutes
    total_minutes = ((end_time - start_time) / 60).to_i

    # On soustrait la pause si elle existe
    if has_break?
      break_duration = ((break_end_time - break_start_time) / 60).to_i
      total_minutes -= break_duration
    end

    self.duration_minutes = [total_minutes, 0].max
  end

  def compute_night_minutes
    return if start_time.blank? || end_time.blank?
    minutes = 0
    current = start_time

    while current < end_time
      # On ne compte la minute de nuit QUE si on n'est pas en pause
      unless in_break?(current)
        minutes += 1 if current.hour >= NIGHT_START || current.hour < NIGHT_END
      end
      current += 1.minute
    end
    self.night_minutes = minutes
  end

  # ============================================================
  # FINANCES & REMUNERATION (RESTENT IDENTIQUES)
  # ============================================================

  def brut
    return 0 if duration_minutes.zero?
    day_pay + night_pay
  end

  def amount_ifm
    contract.ifm(brut).round(2)
  end

  def amount_cp
    base = brut + amount_ifm
    contract.cp(base).round(2)
  end

  def km_payment_final
    contract.km_payment(effective_km.to_f, recommended: recommended)
  end

  def net
    (brut * 0.78).round(2)
  end

  def net_total
    val_brut = brut
    val_ifm  = amount_ifm
    val_cp   = amount_cp
    val_km   = km_payment_final

    net_salary = (val_brut * 0.78).round(2)
    net_ifm    = (val_ifm  * 0.78).round(2)
    net_cp     = (val_cp   * 0.78).round(2)

    (net_salary + net_ifm + net_cp + val_km).round(2)
  end

  def total_payment
    brut + amount_ifm + amount_cp + km_payment_final
  end

  # ============================================================
  # LOGIQUE DE SYNCHRONISATION DES DATES
  # ============================================================

  def fix_timestamps_with_correct_date
    return unless date.present?

    # Synchronisation start/end
    self.start_time = Time.zone.parse("#{date} #{start_time.strftime('%H:%M:%S')}") if start_time.present?
    self.end_time = Time.zone.parse("#{date} #{end_time.strftime('%H:%M:%S')}") if end_time.present?

    # Synchronisation des heures de pause
    if break_start_time.present?
      self.break_start_time = Time.zone.parse("#{date} #{break_start_time.strftime('%H:%M:%S')}")
    end
    if break_end_time.present?
      self.break_end_time = Time.zone.parse("#{date} #{break_end_time.strftime('%H:%M:%S')}")
    end
  end

  def ensure_end_time_is_on_correct_day
    return if start_time.blank? || end_time.blank?
    self.end_time += 1.day if end_time <= start_time

    # Si la pause finit après le début (ex: pause à minuit), on gère aussi
    if has_break? && break_end_time <= break_start_time
      self.break_end_time += 1.day
    end
  end

  # ============================================================
  # VALIDATIONS PRIVÉES
  # ============================================================
  private

  def validate_break_consistency
    return unless has_break?

    if break_end_time <= break_start_time
      errors.add(:break_end_time, "doit être après l'heure de début de pause")
    end

    if break_start_time < start_time || break_end_time > end_time
      errors.add(:base, "La coupure doit être comprise dans l'amplitude de la mission")
    end
  end

  def end_after_start
    return if start_time.blank? || end_time.blank?
    return if end_time > start_time
    errors.add(:end_time, "doit être après l'heure de début")
  end

  def no_overlap_with_existing_sessions
    return unless contract.present? && date.present? && start_time.present? && end_time.present?

    new_start_dt = Time.zone.parse("#{date} #{start_time.strftime('%H:%M:%S')}")
    new_end_dt   = Time.zone.parse("#{date} #{end_time.strftime('%H:%M:%S')}")
    new_end_dt += 1.day if new_end_dt <= new_start_dt

    date_range = (date - 1.day)..(date + 1.day)
    existing_sessions = WorkSession.joins(:contract).where(contracts: { user_id: contract.user_id })
                                   .where(date: date_range).where.not(id: id)

    has_overlap = existing_sessions.any? do |session|
      new_start_dt < session.end_time && new_end_dt > session.start_time
    end

    errors.add(:base, 'Cette mission chevauche une autre mission déjà enregistrée.') if has_overlap
  end

  # ... Méthodes de calcul brut privées (inchangées) ...
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

  def compute_effective_km
    if km_custom.present?
      self.effective_km = km_custom.to_f
    else
      api_km = kilometer_logs.sum(:distance).to_f
      self.effective_km = api_km.positive? ? api_km : 0.0
    end
  end
end
