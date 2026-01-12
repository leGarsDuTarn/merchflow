class CancelRecruitmentService
  attr_reader :error_message

  def initialize(job_application)
    @application = job_application
    @offer       = job_application.job_offer
    @merch       = job_application.merch
  end

  def call
    # N peut être annulé que si c'était accepté
    unless @application.status == 'accepted'
      @error_message = "Cette candidature n'est pas validée."
      return false
    end

    ActiveRecord::Base.transaction do
      # Supprimer les sessions de travail PRÉCISÉMENT liées à cette offre
      # Se base pas sur les dates, mais sur l'ID de l'offre.
      WorkSession.joins(:contract)
                 .where(job_offer_id: @offer.id)
                 .where(contracts: { user_id: @merch.id })
                 .destroy_all

      # 2. Repasser la candidature en 'pending'
      @application.update!(status: 'pending')

      if @offer.status == 'filled'
        @offer.update!(status: 'published')
      end
    end

    true
  rescue StandardError => e
    @error_message = "Une erreur est survenue : #{e.message}"
    false
  end
end
