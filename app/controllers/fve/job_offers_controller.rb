# app/controllers/fve/job_offers_controller.rb
module Fve
  class JobOffersController < ApplicationController
    before_action :authenticate_user!
    before_action :verify_fve
    before_action :set_job_offer, only: [:show, :edit, :update, :destroy, :accept_candidate, :reject_candidate]

    def index
      authorize [:fve, JobOffer]
      @job_offers = policy_scope([:fve, JobOffer]).order(created_at: :desc)
    end

    def show
      authorize [:fve, @job_offer]
      # Correction : on inclut :merch (et non :user) pour correspondre à ton modèle
      @job_applications = @job_offer.job_applications.includes(:merch).order(created_at: :desc)
    end

    def new
      @job_offer = JobOffer.new
      authorize [:fve, @job_offer]
      @job_offer.hourly_rate = 12.02
      @job_offer.km_rate = 0.25

      if current_user
        @job_offer.contact_email = current_user.email
        @job_offer.contact_phone = current_user.phone_number if current_user.respond_to?(:phone_number)
      end
    end

    def create
      @job_offer = current_user.created_job_offers.build(job_offer_params)
      @job_offer.status = 'published'
      authorize [:fve, @job_offer]

      if @job_offer.save
        redirect_to fve_job_offers_path, notice: 'Annonce publiée avec succès ! 🚀'
      else
        render :new, status: :unprocessable_entity
      end
    end

    # AJOUT : Méthode edit nécessaire pour le callback et la vue edit
    def edit
      authorize [:fve, @job_offer]
    end

    # AJOUT : Méthode update nécessaire pour le callback et l'enregistrement
    def update
      authorize [:fve, @job_offer]
      if @job_offer.update(job_offer_params)
        redirect_to fve_job_offer_path(@job_offer), notice: 'Annonce mise à jour !'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def accept_candidate
      authorize [:fve, @job_offer], :accept_candidate?
      application = @job_offer.job_applications.find(params[:application_id])
      service = RecruitMerchService.new(application)

      if service.call
        redirect_to fve_job_offer_path(@job_offer), notice: 'Candidat recruté, contrat et planning générés.'
      else
        redirect_to fve_job_offer_path(@job_offer), alert: service.error_message
      end
    end

    def destroy
      authorize [:fve, @job_offer]
      @job_offer.destroy
      redirect_to fve_job_offers_path, notice: 'Annonce supprimée.'
    end

    # app/controllers/fve/job_offers_controller.rb

  def reject_candidate
    authorize [:fve, @job_offer], :accept_candidate? # On réutilise la règle existante
    @application = @job_offer.job_applications.find(params[:application_id])

    if @application.update(status: 'rejected')

      # Nettoyage : Si le candidat était déjà accepté, on cherche le contrat lié
      # On cherche un contrat entre ce candidat et ce recruteur
      contract = Contract.find_by(merch_id: @application.merch_id, fve_id: current_user.id)

      if contract
        # On supprime les sessions de travail liées à cette offre précise
        # pour ne pas supprimer tout le planning du Merch (s'il a d'autres missions avec ce FVE)
        WorkSession.where(contract: contract, store: @job_offer.store_name, date: @job_offer.start_date..@job_offer.end_date).destroy_all

        # Optionnel : Tu peux décider de supprimer le contrat si c'était le seul
        # contract.destroy if contract.work_sessions.empty?
      end

      redirect_to fve_job_offer_path(@job_offer), notice: 'Candidature refusée et planning nettoyé.'
    else
      redirect_to fve_job_offer_path(@job_offer), alert: "Impossible de modifier le statut."
    end
  end

    private

    def set_job_offer
      @job_offer = JobOffer.find(params[:id])
    end

    def verify_fve
      unless current_user&.fve?
        redirect_to root_path, alert: 'Accès réservé.'
      end
    end

    def job_offer_params
      params.require(:job_offer).permit(
        :title, :description, :mission_type, :contract_type,
        :start_date, :end_date, :break_start_time, :break_end_time,
        :company_name, :store_name, :address, :zipcode, :city, :department_code,
        :hourly_rate, :night_rate, :km_rate, :km_limit, :km_unlimited,
        :headcount_required, :ifm_rate, :cp_rate,
        :contact_email, :contact_phone
      )
    end
  end
end
