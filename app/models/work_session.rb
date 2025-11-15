class WorkSession < ApplicationRecord
  # ============================================================
  # RELATIONS
  # ============================================================

  belongs_to :contract
  has_many :kilometer_logs, dependent: :destroy

  # ============================================================
  # VALIDATIONS
  # ============================================================

  validates :date, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validate  :end_after_start

  validates :break_minutes,
            numericality: { greater_than_or_equal_to: 0 }

  # ============================================================
  # CONSTANTES
  # ============================================================

  NIGHT_START = 21 # 21h
  NIGHT_END   = 6  # 6h

  # ============================================================
  # CALLBACKS
  # ============================================================

  # Avant toute validation → on calcule tout
  before_validation :ensure_end_time_is_on_correct_day
  before_validation :compute_duration
  before_validation :compute_night_minutes
  before_validation :check_meal_eligibility
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

  # Si l'utilisateur met 20h → 02h sans changer de date : on corrige automatiquement
  def ensure_end_time_is_on_correct_day
    return if start_time.blank? || end_time.blank?

    if end_time <= start_time
      # on ajoute 1 jour à l'heure de fin
      self.end_time = end_time + 1.day
    end
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
      hour = current.hour

      if hour >= NIGHT_START || hour < NIGHT_END
        minutes += 1
      end

      current += 1.minute
    end

    self.night_minutes = minutes
  end

  # ============================================================
  # MEAL CHECK
  # ============================================================

  def check_meal_eligibility
    return if duration_minutes.blank?

    self.meal_eligible = duration_minutes >= meal_hours_required * 60
  end

  # ============================================================
  # KM EFFECTIFS
  # ============================================================

  def compute_effective_km
    if km_custom.present?
      self.effective_km = km_custom
    else
      self.effective_km = kilometer_logs.sum(:distance)
    end
  end

  # ============================================================
  # CALCUL BRUT
  # ============================================================

  def brut
    return 0 if duration_minutes.zero?

    hours_day   = ((duration_minutes - night_minutes) / 60.0).round(2)
    hours_night = (night_minutes / 60.0).round(2)

    day_pay   = hours_day   * contract.hourly_rate
    night_pay = hours_night * contract.night_hourly_rate

    day_pay + night_pay
  end

  # ============================================================
  # TOTAL REMUNERATION (brut + IFM + CP + frais repas + km)
  # ============================================================

  def total_payment
    brut_value = brut
    ifm = contract.ifm(brut_value)
    cp  = contract.cp(brut_value)
    km_pay = contract.km_payment(effective_km.to_f, recommended: recommended)

    meal = meal_eligible ? meal_allowance : 0

    brut_value + ifm + cp + km_pay + meal
  end
end
