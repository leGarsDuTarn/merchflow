class MissionProposal < ApplicationRecord
  # ============================================================
  # RELATIONS
  # ============================================================
  belongs_to :fve, class_name: 'User'
  belongs_to :merch, class_name: 'User'

  # ============================================================
  # STATUTS
  # ============================================================
  enum :status, { pending: 'pending', accepted: 'accepted', declined: 'declined', cancelled: 'cancelled' }

  # ============================================================
  # VALIDATIONS ET GARDE-FOU
  # ============================================================
  validates :date, :start_time, :end_time, :company, :agency, presence: true
  # Assure que le champ KM est renseigné
  validates :effective_km, presence: { message: "Vous devez renseigner le nombre de kilomètres effectifs." }

  # Validations du rôle
  validate :fve_must_be_fve
  validate :merch_must_be_merch

  # Interdit les missions qui passent minuit
  validate :end_time_must_be_after_start_time

  # Vérifie le chevauchement horaire avec d'autres propositions
  validate :no_overlap_with_existing_proposals

  # NOTE: On permet plusieurs propositions sur le même créneau
  # Le conflit avec les WorkSession sera vérifié au moment de l'acceptation

  # ============================================================
  # SCOPES
  # ============================================================

  # Scope pour afficher uniquement les propositions non expirées
  # Cette scope s'assure que la mission n'est pas déjà passée.
  scope :active_opportunities, -> {
    # Heure du serveur local, mais demandons à PostgreSQL de faire la conversion
    # pour garantir la cohérence des colonnes non-zonées.

    where("
      (date > CURRENT_DATE)
      OR
      (
        date = CURRENT_DATE AND
        (date::timestamp + start_time::time::interval) > (NOW() AT TIME ZONE 'Europe/Paris')::timestamp
      )
    ")
  }

  scope :search_by_merch_name, ->(query) {
    return all if query.blank?

    search_term = "%#{query}%"

    # Jointure avec la table users via l'alias 'merch' et recherche sur les colonnes du Merch
    joins(:merch)
      .where("users.firstname ILIKE :search OR users.lastname ILIKE :search OR users.username ILIKE :search", search: search_term)
  }

  scope :by_company, ->(company_name) {
    return all if company_name.blank?
    where("company ILIKE ?", "%#{company_name}%")
  }

  scope :by_date_range, ->(start_date_param, end_date_param) {
    start_date = start_date_param.present? ? (Date.parse(start_date_param) rescue nil) : nil
    end_date = end_date_param.present? ? (Date.parse(end_date_param) rescue nil) : nil

    if start_date && end_date
      where(date: start_date..end_date)
    elsif start_date
      where("date >= ?", start_date)
    elsif end_date
      where("date <= ?", end_date)
    else
      all
    end
  }

  scope :by_merch_preference, ->(preference) {
    return all unless preference.present?

    case preference.to_sym
    when :merch
      # Joindre merch -> merch_setting
      joins(merch: :merch_setting).where(merch_settings: { role_merch: true })
    when :anim
      joins(merch: :merch_setting).where(merch_settings: { role_anim: true })
    else
      all
    end
  }

  scope :overlapping, ->(start_time, end_time) {
    where("
      (mission_proposals.start_time < :end_time) AND (mission_proposals.end_time > :start_time)
    ", start_time: start_time, end_time: end_time)
  }

  # ============================================================
  # TRANSFORMER EN MISSION - VERSION OPTIMISÉE
  # ============================================================
  def accept!
    return unless pending?

    ActiveRecord::Base.transaction do
      # 0. VÉRIFICATION CRITIQUE : Pas de conflit avec des missions déjà validées
      if conflicts_with_existing_work_session?
        errors.add(:base, "Impossible d'accepter : Ce créneau chevauche une mission déjà validée dans votre planning.")
        raise ActiveRecord::Rollback
      end

      # 1. On cherche le contrat EXISTANT entre ce Merch et cette Agence.
      contract = Contract.find_by!(
        user: merch,
        agency: agency
      )

      # 2. On met à jour le statut de la proposition
      update!(status: :accepted)

      # 3. On crée la vraie WorkSession (Mission validée) rattachée à ce contrat existant
      WorkSession.create!(
        contract: contract,
        date: date,
        start_time: start_time,
        end_time: end_time,
        company: company,
        store: store_name,
        store_full_address: store_address,
        hourly_rate: hourly_rate,
        effective_km: effective_km,
        status: :accepted,
        notes: "Mission acceptée via proposition FVE. Message initial : #{message}"
      )

      # 4. BONUS : Décliner automatiquement les autres propositions qui chevauchent
      decline_conflicting_proposals!
    end
  rescue ActiveRecord::RecordNotFound
    errors.add(:base, "Impossible d'accepter : Aucun contrat actif trouvé pour l'agence #{agency}.")
    false
  end

  # ============================================================
  # VÉRIFIER CONFLIT AVEC WORKSESSION EXISTANTE
  # Appelé au moment de l'acceptation pour éviter les double-bookings
  # ============================================================
  def conflicts_with_existing_work_session?
    return false unless date.present? && start_time.present? && end_time.present? && merch_id.present?

    new_start_dt = DateTime.new(date.year, date.month, date.day, start_time.hour, start_time.min, start_time.sec)
    new_end_dt = DateTime.new(date.year, date.month, date.day, end_time.hour, end_time.min, end_time.sec)
    new_end_dt += 1.day if end_time <= start_time

    date_range = (date - 1.day)..(date + 1.day)

    conflicting_sessions = WorkSession
      .joins(:contract)
      .where(contracts: { user_id: merch_id })
      .where(date: date_range)
      .where(status: [:accepted, :pending]) # Vérifier les sessions validées ou en attente

    conflicting_sessions.any? do |session|
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
  end

  # ============================================================
  # DÉCLINER AUTOMATIQUEMENT LES PROPOSITIONS CONFLICTUELLES
  # Appelé après l'acceptation d'une proposition
  # ============================================================
  def decline_conflicting_proposals!
    return unless date.present? && start_time.present? && end_time.present? && merch_id.present?

    new_start_dt = DateTime.new(date.year, date.month, date.day, start_time.hour, start_time.min, start_time.sec)
    new_end_dt = DateTime.new(date.year, date.month, date.day, end_time.hour, end_time.min, end_time.sec)
    new_end_dt += 1.day if end_time <= start_time

    date_range = (date - 1.day)..(date + 1.day)

    # Trouver toutes les autres propositions en attente pour ce Merch
    conflicting_proposals = MissionProposal
      .where(merch_id: merch_id)
      .where(date: date_range)
      .where(status: :pending)
      .where.not(id: id)

    conflicting_proposals.each do |proposal|
      proposal_start = DateTime.new(
        proposal.date.year,
        proposal.date.month,
        proposal.date.day,
        proposal.start_time.hour,
        proposal.start_time.min,
        proposal.start_time.sec
      )

      proposal_end = DateTime.new(
        proposal.date.year,
        proposal.date.month,
        proposal.date.day,
        proposal.end_time.hour,
        proposal.end_time.min,
        proposal.end_time.sec
      )

      proposal_end += 1.day if proposal.end_time <= proposal.start_time

      # Si chevauchement, décliner automatiquement
      if proposal_start < new_end_dt && proposal_end > new_start_dt
        proposal.update(
          status: :declined,
          notes: "Déclinée automatiquement : créneau déjà pris par une autre mission acceptée."
        )

        # BONUS : Vous pouvez ajouter une notification ici
        # ProposalMailer.auto_declined(proposal).deliver_later
      end
    end
  end

  private

  # ============================================================
  # VALIDATIONS PERSONNELLES
  # ============================================================

  def fve_must_be_fve
    errors.add(:fve, 'doit être un FVE') unless fve&.fve?
  end

  def merch_must_be_merch
    errors.add(:merch, 'doit être un Merch') unless merch&.merch?
  end

  def end_time_must_be_after_start_time
    return if start_time.blank? || end_time.blank?

    # Si l'heure de fin n'est pas après l'heure de début, c'est une mission qui passe minuit.
    if end_time <= start_time
      errors.add(:end_time, 'Saisie au-delà de minuit détectée. Veuillez diviser la mission en deux : Jour 1 (max 23:59) et Jour 2 (min 00:00).')
    end
  end

  # ============================================================
  # GARDE-FOU : Chevauchement entre propositions
  # VERSION CORRIGÉE ET OPTIMISÉE
  # ============================================================
  def no_overlap_with_existing_proposals
    return unless date.present? && start_time.present? && end_time.present? && merch_id.present?

    # 1. Construire les datetime complets pour la nouvelle proposition
    new_start_dt = DateTime.new(date.year, date.month, date.day, start_time.hour, start_time.min, start_time.sec)
    new_end_dt = DateTime.new(date.year, date.month, date.day, end_time.hour, end_time.min, end_time.sec)

    # NOTE : Normalement end_time > start_time car vous interdisez les missions passant minuit
    # Mais on ajoute une sécurité au cas où
    if end_time <= start_time
      # Ce cas devrait déjà être bloqué par end_time_must_be_after_start_time
      # mais on l'ajoute pour la cohérence
      new_end_dt += 1.day
    end

    # 2. Récupérer les propositions du même Merch dans une fenêtre de ±1 jour
    # (au cas où il y aurait des missions qui débordent, même si interdites)
    date_range = (date - 1.day)..(date + 1.day)

    overlapping_proposals = MissionProposal
      .where(merch_id: merch_id)
      .where(date: date_range)
      .where.not(id: id)
      .where.not(status: [:declined, :cancelled]) # Ignorer les propositions annulées/refusées

    # 3. Vérifier le chevauchement en Ruby (plus fiable que SQL pour ce cas)
    has_overlap = overlapping_proposals.any? do |proposal|
      existing_start = DateTime.new(
        proposal.date.year,
        proposal.date.month,
        proposal.date.day,
        proposal.start_time.hour,
        proposal.start_time.min,
        proposal.start_time.sec
      )
      
      existing_end = DateTime.new(
        proposal.date.year,
        proposal.date.month,
        proposal.date.day,
        proposal.end_time.hour,
        proposal.end_time.min,
        proposal.end_time.sec
      )

      # Ajuster si la proposition existante passe minuit (normalement impossible)
      existing_end += 1.day if proposal.end_time <= proposal.start_time

      # Logique de chevauchement
      existing_start < new_end_dt && existing_end > new_start_dt
    end

    if has_overlap
      errors.add(:base, 'Cette mission chevauche une autre proposition existante pour ce prestataire. Vérifiez vos horaires.')
    end
  end
end
