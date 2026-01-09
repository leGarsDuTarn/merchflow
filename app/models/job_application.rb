class JobApplication < ApplicationRecord
  belongs_to :job_offer
  belongs_to :merch, class_name: 'User', foreign_key: 'merch_id'

  before_destroy :clean_work_sessions_before_destroy
  after_update :clean_work_sessions, if: :status_changed_to_not_accepted?

  validates :merch_id, uniqueness: { scope: :job_offer_id, message: "Vous avez déjà postulé à cette offre" }

  scope :pending, -> { where(status: 'pending') }
  scope :accepted, -> { where(status: 'accepted') }

  private

  def status_changed_to_not_accepted?
    status_before_last_save == 'accepted' && status != 'accepted'
  end

  def clean_work_sessions_before_destroy
    # Seulement si la candidature était acceptée
    return unless status == 'accepted'

    Rails.logger.info "🚨 BEFORE_DESTROY déclenché pour JobApplication ##{id}"
    clean_work_sessions
  end

  def clean_work_sessions
    fve = job_offer.fve
    agency_code = fve.respond_to?(:agency) ? fve.agency : nil

    Rails.logger.info "🔍 [clean_work_sessions] Recherche contrat: user_id=#{merch_id}, agency=#{agency_code.inspect}"

    # ✅ Recherche cohérente avec user_id + agency
    contract = Contract.find_by(
      user_id: merch_id,
      agency: agency_code
    )

    if contract
      sessions_to_delete = WorkSession.where(
        contract: contract,
        job_offer_id: job_offer_id
      )

      deleted_count = sessions_to_delete.destroy_all.size

      Rails.logger.info "🗑️ Suppression de #{deleted_count} work_session(s) pour le contrat ##{contract.id}"
      Rails.logger.info "   Sessions IDs supprimées: #{sessions_to_delete.pluck(:id).inspect}"
    else
      Rails.logger.warn "⚠️ Aucun contrat trouvé pour user_id=#{merch_id}, agency=#{agency_code}"
      Rails.logger.warn "   Job offer: #{job_offer_id}, FVE: #{job_offer.fve_id}"
      Rails.logger.warn "   Contrats existants pour ce user: #{Contract.where(user_id: merch_id).pluck(:id, :agency).inspect}"
    end
  end
end
