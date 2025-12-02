class MissionProposal < ApplicationRecord
  # RELATIONS
  belongs_to :fve, class_name: 'User'
  belongs_to :merch, class_name: 'User'

  # STATUTS
  enum :status, { pending: 'pending', accepted: 'accepted', declined: 'declined', cancelled: 'cancelled' }

  # VALIDATIONS
  validates :date, :start_time, :end_time, :company, :agency, presence: true
  validate :fve_must_be_fve
  validate :merch_must_be_merch

  # =========================================================
  # 🔥 LA MÉTHODE PIVOT : TRANSFORMER EN MISSION
  # =========================================================
  def accept!
    return unless pending?

    ActiveRecord::Base.transaction do
      # 1. On cherche le contrat EXISTANT entre ce Merch et cette Agence.
      # ⚠️ STRICT : On utilise find_by! qui lève une erreur si le contrat n'existe pas.
      # L'application ne crée JAMAIS de contrat automatiquement.
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
        status: :accepted,       # La mission naît directement 'Acceptée'
        notes: "Mission acceptée via proposition FVE. Message initial : #{message}"
      )
    end
  rescue ActiveRecord::RecordNotFound
    # Sécurité supplémentaire : Si jamais le contrat a été supprimé entre temps
    errors.add(:base, "Impossible d'accepter : Aucun contrat actif trouvé pour l'agence #{agency}.")
    false
  end

  private

  def fve_must_be_fve
    errors.add(:fve, 'doit être un FVE') unless fve&.fve?
  end

  def merch_must_be_merch
    errors.add(:merch, 'doit être un Merch') unless merch&.merch?
  end
end
