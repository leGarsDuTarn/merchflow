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
  # Validation du chevauchement horaire pour éviter les double-réservations
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

  # ============================================================
  # SCOPES - pour le dashboard
  # ============================================================
  scope :current_month, -> {
    where(date: Date.current.beginning_of_month..Date.current.end_of_month)
  }

  # ============================================================
  # CLASSE METHOD
  # ============================================================
  def self.create_from_proposal(proposal)
    # Trouver le contrat Merch-Agence le plus récent pour l'agence donnée
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

    # 2) KM provenant des logs (si l'API a écrit dedans)
    api_km = kilometer_logs.sum(:distance).to_f
    if api_km.positive?
      self.effective_km = api_km
      return
    end

    # 3) Fallback si rien du tout
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
    # Récupérer les montants bruts des compléments
    amount_ifm = contract.ifm(brut).round(2)
    amount_cp  = contract.cp(brut).round(2)

    # On passe 'effective_km' pour calculer les frais kilométriques
    amount_km  = contract.km_payment(effective_km).round(2)

    # Calculer le net des compléments (Net = montant × 0.78)
    net_ifm = (amount_ifm * 0.78).round(2)
    net_cp  = (amount_cp  * 0.78).round(2)

    # On additionne tout (Net Salaire + Net IFM + Net CP + KM)
    (net.round(2) + net_ifm + net_cp + amount_km).round(2)
  end

  # ============================================================
  # MÉTHODES PRIVÉES
  # ============================================================
  private

  # ============================================================
  # VALIDATION : Pas de chevauchement entre sessions
  # VERSION CORRIGÉE ET OPTIMISÉE
  # ============================================================
  def no_overlap_with_existing_sessions
    return unless contract.present? && date.present? && start_time.present? && end_time.present?

    user_id = contract.user_id

    # 1. Construire les datetime complets pour la nouvelle session
    new_start_dt = DateTime.new(date.year, date.month, date.day, start_time.hour, start_time.min, start_time.sec)
    new_end_dt = DateTime.new(date.year, date.month, date.day, end_time.hour, end_time.min, end_time.sec)

    # Si end_time <= start_time, la mission passe minuit
    new_end_dt += 1.day if end_time <= start_time

    # 2. Récupérer toutes les sessions de l'utilisateur dans une fenêtre de ±1 jour
    # (pour capturer les missions de nuit qui peuvent déborder)
    date_range = (date - 1.day)..(date + 1.day)

    existing_sessions = WorkSession
      .joins(:contract)
      .where(contracts: { user_id: user_id })
      .where(date: date_range)
      .where.not(id: id)

    # 3. Vérifier le chevauchement
    has_overlap = existing_sessions.any? do |session|
      # Construire les datetime de la session existante
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

      # Ajuster si la session existante passe minuit
      existing_end += 1.day if session.end_time <= session.start_time

      # Logique de chevauchement : deux intervalles se chevauchent si
      # l'un commence avant que l'autre ne finisse ET vice versa
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
