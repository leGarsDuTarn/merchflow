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
    # 1) KM renseigné manuellement par l'utilisateur
    if km_custom.present?
      self.effective_km = km_custom.to_f
      return
    end

    # 2) KM provenant des logs (si l’API a écrit dedans)
    api_km = kilometer_logs.sum(:distance).to_f
    if api_km.positive?
      self.effective_km = api_km
      return
    end

    # 3) Fallback si rien du tout (l’API fera une MAJ après création)
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
  # TOTAL REMUNERATION
  # ============================================================
  def total_payment
    brut +
      contract.ifm(brut) +
      contract.cp(brut) +
      km_payment_final
  end

  def km_payment_final
    contract.km_payment(effective_km.to_f, recommended: recommended)
  end

  # ============================================================
  # NET & NET TOTAL (public)
  # ============================================================
  def net
    # On retire 22% du salaire brut
    (brut * (1 - 0.22)).round(2)
  end

  def net_total
    # Assurez-vous que amount_ifm et amount_cp sont arrondis
    amount_ifm = contract.ifm(brut).round(2)
    amount_cp  = contract.cp(brut).round(2)

    # On passe 'effective_km' pour calculer les frais kilométriques
    amount_km  = contract.km_payment(effective_km).round(2)

    # Net = montant × 0.78
    net_ifm = (amount_ifm * 0.78).round(2)
    net_cp  = (amount_cp  * 0.78).round(2)

    # On additionne tout
    # S'assurer que 'net' est également arrondi si ce n'est pas déjà le cas
    (net.round(2) + net_ifm + net_cp + amount_km).round(2)
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
end
