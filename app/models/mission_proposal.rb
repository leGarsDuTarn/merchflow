class MissionProposal < ApplicationRecord
  # RELATIONS
  belongs_to :fve, class_name: 'User'
  belongs_to :merch, class_name: 'User'

  # STATUTS
  enum :status, { pending: 'pending', accepted: 'accepted', declined: 'declined', cancelled: 'cancelled' }

  # =========================================================
  # VALIDATIONS ET GARDE-FOU
  # =========================================================
  validates :date, :start_time, :end_time, :company, :agency, presence: true

  # Validations du rôle
  validate :fve_must_be_fve
  validate :merch_must_be_merch

  # Interdit les missions qui passent minuit
  validate :end_time_must_be_after_start_time

  # Vérifie le chevauchement horaire
  validate :no_overlap_with_existing_proposals

  # =========================================================
  # SCOPE
  # =========================================================

  # Scope pour afficher uniquement les propositions non expirées
  # Cette scope s'assure que la mission n'est pas déjà passée.
  scope :active_opportunities, -> {
    where('date > ?', Date.current)
      .or(
        where(date: Date.current)
        .where("start_time::time > ?", Time.current.strftime('%H:%M:%S'))
      )
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

  # =========================================================
  # TRANSFORMER EN MISSION
  # =========================================================
  def accept!
    return unless pending?

    ActiveRecord::Base.transaction do
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
    end
  rescue ActiveRecord::RecordNotFound
    errors.add(:base, "Impossible d'accepter : Aucun contrat actif trouvé pour l'agence #{agency}.")
    false
  end

  private

  # =========================================================
  # VALIDATIONS PERSONNELLES
  # =========================================================

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

  # GARDE-FOU (Chevauchement)
  # Dans app/models/mission_proposal.rb (ou le fichier contenant cette méthode)

  def no_overlap_with_existing_proposals
    return unless date.present? && start_time.present? && end_time.present? && merch_id.present?

    # 1. Construire les datetime complets pour la NOUVELLE proposition (celle en cours de validation)
    new_start_dt = date.to_datetime.change(hour: start_time.hour, min: start_time.min)
    new_end_dt   = date.to_datetime.change(hour: end_time.hour, min: end_time.min)

    # Ajuster si la proposition est une mission de nuit (end_time a été modifié)
    new_end_dt += 1.day if end_time.day != start_time.day

    # 2. Récupérer TOUTES les propositions pour le même Merch (sauf la courante)
    existing_proposals = MissionProposal.where(merch_id: merch_id)
                                      .where.not(id: id)

    # 3. Vérifier le chevauchement en itérant en Ruby
    has_overlap = existing_proposals.any? do |proposal|
    # Construire les datetime de la proposition existante
    existing_start = proposal.date.to_datetime.change(
      hour: proposal.start_time.hour,
      min: proposal.start_time.min
    )
    existing_end = proposal.date.to_datetime.change(
      hour: proposal.end_time.hour,
      min: proposal.end_time.min
    )

    # Ajuster si la proposition existante est une mission de nuit
    existing_end += 1.day if proposal.end_time.day != proposal.start_time.day

    # Logique de chevauchement : C < B AND D > A
    existing_start < new_end_dt && existing_end > new_start_dt
    end

    if has_overlap
      errors.add(:base, 'Cette mission chevauche une autre proposition existante pour ce prestataire. Vérifiez vos horaires.')
    end
  end
end
