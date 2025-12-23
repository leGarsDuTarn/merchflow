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
  validate  :validate_break_consistency

  # ============================================================
  # ENUM & SCOPES
  # ============================================================
  enum :status, { pending: 0, accepted: 1, declined: 2 }

  scope :for_month, ->(year, month) { where(date: Date.new(year, month).all_month).order(:date, :start_time) }
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
  NIGHT_START = 21
  NIGHT_END   = 6

  # ============================================================
  # CALLBACKS
  # ============================================================
  # 1. On nettoie les entrées (virgules) AVANT tout calcul
  before_validation :normalize_decimal_fields

  before_validation :fix_timestamps_with_correct_date
  before_validation :ensure_end_time_is_on_correct_day
  before_validation :compute_duration
  before_validation :compute_night_minutes
  before_validation :compute_effective_km

  # ============================================================
  # MÉTHODES PUBLIQUES
  # ============================================================

  def has_break?
    break_start_time.present? && break_end_time.present?
  end

  def in_break?(time)
    return false unless has_break?
    time >= break_start_time && time < break_end_time
  end

  def compute_effective_km
    if km_custom.present?
      self.effective_km = km_custom.to_f
    else
      api_km = kilometer_logs.sum(:distance).to_f
      self.effective_km = api_km.positive? ? api_km : 0.0
    end
  end

  def compute_duration
    return if start_time.blank? || end_time.blank?
    total = ((end_time - start_time) / 60).to_i
    if has_break?
      break_duration = ((break_end_time - break_start_time) / 60).to_i
      total -= break_duration
    end
    self.duration_minutes = [total, 0].max
  end

  def compute_night_minutes
    return if start_time.blank? || end_time.blank?
    minutes = 0
    current = start_time
    while current < end_time
      unless in_break?(current)
        minutes += 1 if current.hour >= NIGHT_START || current.hour < NIGHT_END
      end
      current += 1.minute
    end
    self.night_minutes = minutes
  end

  # --- FINANCES ---

  # Helper pour sommer les frais annexes
  def total_fees
    (fee_meal || 0) + (fee_parking || 0) + (fee_toll || 0)
  end

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

  # Mise à jour : inclut maintenant les frais annexes
  def net_total
    val_brut = brut
    val_ifm  = amount_ifm
    val_cp   = amount_cp
    val_km   = km_payment_final
    val_fees = total_fees # Ajout

    net_salary = (val_brut * 0.78).round(2)
    net_ifm    = (val_ifm  * 0.78).round(2)
    net_cp     = (val_cp   * 0.78).round(2)

    (net_salary + net_ifm + net_cp + val_km + val_fees).round(2)
  end

  # Mise à jour : inclut maintenant les frais annexes
  def total_payment
    brut + amount_ifm + amount_cp + km_payment_final + total_fees
  end

  # --- NORMALISATION ---

  def fix_timestamps_with_correct_date
    return unless date.present?
    self.start_time = Time.zone.parse("#{date} #{start_time.strftime('%H:%M:%S')}") if start_time.present?
    self.end_time = Time.zone.parse("#{date} #{end_time.strftime('%H:%M:%S')}") if end_time.present?
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
    self.break_end_time += 1.day if has_break? && break_end_time <= break_start_time
  end

  # ============================================================
  # MÉTHODES PRIVÉES
  # ============================================================
  private

  def validate_break_consistency
    return unless has_break?
    errors.add(:break_end_time, "doit être après l'heure de début de pause") if break_end_time <= break_start_time
    if break_start_time < start_time || break_end_time > end_time
      errors.add(:base, "La coupure doit être comprise dans l'amplitude de la mission")
    end
  end

  def end_after_start
    return if start_time.blank? || end_time.blank?
    errors.add(:end_time, "doit être après l'heure de début") if end_time <= start_time
  end

  def no_overlap_with_existing_sessions
    return unless contract.present? && date.present? && start_time.present? && end_time.present?

    new_start = Time.zone.parse("#{date} #{start_time.strftime('%H:%M:%S')}")
    new_end   = Time.zone.parse("#{date} #{end_time.strftime('%H:%M:%S')}")
    new_end  += 1.day if new_end <= new_start

    date_range = (date - 1.day)..(date + 1.day)
    existing_sessions = WorkSession.joins(:contract).where(contracts: { user_id: contract.user_id })
                                   .where(date: date_range).where.not(id: id)

    has_overlap = existing_sessions.any? do |session|
      new_start < session.end_time && new_end > session.start_time
    end

    errors.add(:base, 'Cette mission chevauche une autre mission déjà enregistrée.') if has_overlap
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

  def normalize_decimal_fields
    # Ajout de km_custom et hourly_rate pour sécuriser aussi ces champs
    fields_to_check = %i[fee_meal fee_parking fee_toll]

    fields_to_check.each do |field|
      raw_value = read_attribute_before_type_cast(field)
      if raw_value.is_a?(String) && raw_value.include?(',')
        self[field] = raw_value.tr(',', '.')
      end
    end
  end
end
