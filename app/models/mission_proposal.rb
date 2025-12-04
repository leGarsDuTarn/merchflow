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

  # Vérifie le chevauchement horaire
  validate :no_overlap_with_existing_proposals

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
        estimated_km: estimated_km,
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

  # GARDE-FOU (Chevauchement)
  def no_overlap_with_existing_proposals
    return unless date.present? && start_time.present? && end_time.present?

    # Chercher d'autres propositions pour le même Merch le même jour, excluant l'enregistrement courant (pour les mises à jour)
    scope = MissionProposal.where(merch_id: merch_id, date: date)
                           .where.not(id: id)

    # Condition de chevauchement : (Start Existant < End Nouveau) AND (End Existant > Start Nouveau)
    if scope.exists?([
      '(start_time < ?) AND (end_time > ?)', end_time, start_time
    ])

      errors.add(:base, 'Cette mission chevauche une autre proposition existante pour ce prestataire ce jour-là. Vérifiez vos horaires.')
    end
  end
end
