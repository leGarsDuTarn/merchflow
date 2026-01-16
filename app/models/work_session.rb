class WorkSession < ApplicationRecord
  # ============================================================
  # RELATIONS
  # ============================================================
  belongs_to :contract
  belongs_to :job_offer, optional: true
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
  # SCOPES
  # ============================================================
  scope :for_month, ->(year, month) {
    where(date: Date.new(year, month).all_month).order(:date, :start_time)
  }

  scope :for_year, ->(year) {
    where(date: Date.new(year).all_year).order(:date, :start_time)
  }
  scope :upcoming, -> { where('date >= ?', Date.today).order(:date) }
  scope :past, -> { where('date < ?', Date.today).order(date: :desc) }
  scope :for_user, ->(user) { joins(:contract).where(contracts: { user_id: user.id }) }
  scope :current_month, -> { where(date: Date.current.beginning_of_month..Date.current.end_of_month) }

  scope :search, ->(query) {
    return all if query.blank?
    where('company ILIKE :q OR store ILIKE :q OR date::text ILIKE :q', q: "%#{query}%")
  }

  # ============================================================
  # CLASS METHODS
  # ============================================================
  def self.create_from_proposal(proposal)
    contract = proposal.merch.contracts
                       .where(agency: proposal.agency)
                       .order(created_at: :desc)
                       .first
    return unless contract

    # Logique de fragmentation pour la nuit
    if proposal.end_time > proposal.start_time
      # Cas simple
      create_session(contract, proposal, proposal.date, proposal.start_time, proposal.end_time, proposal.effective_km)
    else
      # Cas nuit traversante : on coupe en deux
      # Partie 1 : Jour J jusqu'à 23:59:59
      end_of_day = proposal.date.to_time.end_of_day
      create_session(contract, proposal, proposal.date, proposal.start_time, end_of_day, proposal.effective_km)

      # Partie 2 : Jour J+1 de 00:00:00 à Fin
      start_of_next_day = proposal.date.tomorrow.to_time.beginning_of_day
      create_session(contract, proposal, proposal.date.tomorrow, start_of_next_day, proposal.end_time, 0.0)
    end
  end

  def self.create_session(contract, proposal, date, start, finish, km)
    WorkSession.create!(
      contract: contract,
      date: date,
      start_time: start,
      end_time: finish,
      hourly_rate: proposal.hourly_rate,
      effective_km: km || 0.0,
      store: proposal.store_name,
      company: proposal.company,
      recommended: false,
      status: :accepted
    )
  end

  # ============================================================
  # CALLBACKS
  # ============================================================
  # On normalise AVANT validation pour éviter l'erreur de format
  before_validation :normalize_decimal_fields
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

  def ensure_end_time_is_on_correct_day
    # Cette méthode reste utile pour les saisies manuelles non fragmentées
    # Mais via le Service, les dates sont déjà justes.
    return if start_time.blank? || end_time.blank?
    self.end_time += 1.day if end_time <= start_time
  end

  # ============================================================
  # CALCUL DUREE & NUIT
  # ============================================================
  def compute_duration
    return if start_time.blank? || end_time.blank?

    # 1. Calcul total brut
    raw_minutes = ((end_time - start_time) / 60).to_i

    # 2. Soustraction de la pause si elle existe
    if break_start_time.present? && break_end_time.present?
      # On s'assure que break_end est bien après break_start (gestion minuit si besoin)
      b_end = break_end_time
      b_end += 1.day if b_end < break_start_time

      break_minutes = ((b_end - break_start_time) / 60).to_i
      raw_minutes -= break_minutes
    end

    # 3. Sécurité pour ne pas avoir de durée négative
    self.duration_minutes = [raw_minutes, 0].max
  end

  def compute_night_minutes
    return if start_time.blank? || end_time.blank? || contract.nil?

    cfg_start = contract.night_start || 21
    cfg_end   = contract.night_end   || 6

    minutes = 0
    current = start_time

    while current < end_time
      # Saute la minute si on est en pause ===
      if in_break?(current)
        current += 1.minute
        next
      end
      # =======================================================

      h = current.hour
      is_night = if cfg_start > cfg_end
                   h >= cfg_start || h < cfg_end
                 else
                   h >= cfg_start && h < cfg_end
                 end
      minutes += 1 if is_night
      current += 1.minute
    end

    self.night_minutes = minutes
  end

  # Helper pour vérifier si une heure donnée tombe dans la pause
  def in_break?(time)
    return false unless break_start_time.present? && break_end_time.present?

    # Gestion du cas où la pause traverse minuit (ex: 23h à 01h)
    b_end = break_end_time
    b_end += 1.day if b_end < break_start_time

    # Si le 'time' testé est le jour précédent mais que la pause a fini le lendemain
    # (Cas complexe, mais généralement WorkSession gère des dates précises)
    time >= break_start_time && time < b_end
  end

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
  # CALCULS FINANCIERS (PUBLIC)
  # ============================================================

  # Calcul du Brut (Base + Nuit)
  def brut
    return 0 if duration_minutes.zero?
    day_pay + night_pay
  end

  # IFM = 10% du Brut total (Base + Nuit)
  def amount_ifm
    contract.ifm(brut).round(2)
  end

  # Les CP se calculent sur (Brut + IFM)
  def amount_cp
    base_calcul = brut + amount_ifm
    contract.cp(base_calcul).round(2)
  end

  # Somme des frais (Repas, Parking, Péage)
  def total_fees
    (fee_meal || 0) + (fee_parking || 0) + (fee_toll || 0)
  end

  # Total Brut + Primes + KM + Frais
  def total_payment
    brut + amount_ifm + amount_cp + km_payment_final + total_fees
  end

  def km_payment_final
    contract.km_payment(effective_km.to_f, recommended: recommended)
  end

  # Net fiscal estimé (Sur le brut de base)
  def net
    (brut * (1 - 0.22)).round(2)
  end

  # Net à payer (Virement final)
  def net_total
    # CORRECTION ICI : On appelle km_payment_final pour être sûr d'avoir
    # le même montant que celui affiché dans le détail (50 € et non 25 €).
    amount_km = km_payment_final.round(2)

    # On déduit les charges (approx 22%) sur les primes aussi
    net_ifm = (amount_ifm * 0.78).round(2)
    net_cp  = (amount_cp  * 0.78).round(2)

    # On ajoute les frais (total_fees) qui sont remboursés net
    (net.round(2) + net_ifm + net_cp + amount_km + total_fees).round(2)
  end

  def has_break?
    break_start_time.present? && break_end_time.present?
  end

  # ============================================================
  # MÉTHODES PRIVÉES
  # ============================================================
  private

  # Gestion des virgules pour les frais (Test failure #2)
  def normalize_decimal_fields
    # Liste des champs susceptibles de recevoir des virgules
    %i[hourly_rate fee_meal fee_parking fee_toll km_custom].each do |field|
      raw_value = read_attribute_before_type_cast(field)
      if raw_value.is_a?(String) && raw_value.include?(',')
        self[field] = raw_value.tr(',', '.')
      end
    end
  end

  def no_overlap_with_existing_sessions
    return unless contract.present? && date.present? && start_time.present? && end_time.present?

    user_id = contract.user_id
    new_start_dt = date.to_datetime.change(hour: start_time.hour, min: start_time.min)
    new_end_dt   = date.to_datetime.change(hour: end_time.hour, min: end_time.min)
    new_end_dt += 1.day if end_time.day != start_time.day

    existing_sessions = WorkSession.joins(:contract)
                                   .where(contracts: { user_id: user_id })
                                   .where.not(id: id)

    has_overlap = existing_sessions.any? do |session|
      existing_start = session.date.to_datetime.change(hour: session.start_time.hour, min: session.start_time.min)
      existing_end = session.date.to_datetime.change(hour: session.end_time.hour, min: session.end_time.min)
      existing_end += 1.day if session.end_time.day != session.start_time.day

      existing_start < new_end_dt && existing_end > new_start_dt
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
    # Calcul dynamique : 50.0 devient 0.5
    multiplier = 1 + (contract.night_rate.to_f / 100.0)
    hourly_rate * multiplier
  end

  def night_pay
    hours_night * night_hourly_rate
  end
end
