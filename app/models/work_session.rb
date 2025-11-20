class WorkSession < ApplicationRecord
  # ============================================================
  # RELATIONS
  # ============================================================
  belongs_to :contract
  has_many :kilometer_logs, dependent: :destroy

  # ============================================================
  # VALIDATIONS
  # ============================================================
  validates :date, :start_time, :end_time, presence: true
  validate  :end_after_start
  validates :hourly_rate, numericality: { greater_than: 0 }
  validates :break_minutes, numericality: { greater_than_or_equal_to: 0 }

  # ============================================================
  # CONSTANTES
  # ============================================================
  NIGHT_START = 21 # 21h
  NIGHT_END   = 6  # 6h

  # ============================================================
  # CALLBACKS : recalcul complet avant sauvegarde
  # ============================================================
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
    self.duration_minutes = [total - break_minutes, 0].max
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
    self.effective_km = km_custom.presence || kilometer_logs.sum(:distance)
  end

  # ============================================================
  # CALCUL BRUT
  # ============================================================
  def brut
    return 0 if duration_minutes.zero?
    day_pay + night_pay
  end

  # ============================================================
  # TOTAL REMUNERATION
  # ============================================================
  def total_payment
    brut +
      contract.ifm(brut) +
      contract.cp(brut) +
      km_payment_final
  end

  # ============================================================
  # MÉTHODES PRIVÉES
  # ============================================================
  private

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

  def km_payment_final
    contract.km_payment(effective_km.to_f, recommended: recommended)
  end
end
