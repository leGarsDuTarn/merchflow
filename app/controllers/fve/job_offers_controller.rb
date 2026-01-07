module Fve
  class JobOffersController < ApplicationController
    before_action :authenticate_user!
    before_action :verify_fve
    before_action :set_job_offer, only: [:show, :edit, :update, :destroy, :toggle_status, :accept_candidate, :cancel_candidate, :reject_candidate]

    def index
      authorize [:fve, JobOffer]

      # 1. On récupère les offres de base
      @job_offers = policy_scope([:fve, JobOffer])

      # 2. On applique les filtres en utilisant les NOMS EXACTS de ton modèle
      @job_offers = @job_offers
                      .by_query(params[:query])        # Correspond au scope :by_query (Titre, Ville, CP, Enseigne)
                      .by_type(params[:mission_type])  # Correspond au scope :by_type
                      .by_contract(params[:contract_type]) # Correspond au scope :by_contract
                      .min_rate(params[:min_rate])     # Correspond au scope :min_rate
                      .starting_after(params[:start_date]) # Correspond au scope :starting_after
                      .by_status(params[:status])      # Correspond au scope :by_status
                      .order(created_at: :desc)

      # 3. Logique d'archivage :
      # Si aucun statut n'est sélectionné dans le filtre, on cache les archives via le scope :active
      if params[:status].blank?
        @job_offers = @job_offers.active
      end
    end

    def show
      authorize [:fve, @job_offer]
      @job_applications = @job_offer.job_applications
                                .includes(:merch)
                                .where.not(status: 'archived')
                                .order(created_at: :desc)
    end

    def new
      @job_offer = JobOffer.new
      authorize [:fve, @job_offer]

      if current_user
        @job_offer.contact_email = current_user.email
        @job_offer.contact_phone = current_user.phone_number if current_user.respond_to?(:phone_number)
      end
    end

    def create
      @job_offer = current_user.created_job_offers.build(job_offer_params)
      # Par défaut publié
      @job_offer.status = 'published'
      authorize [:fve, @job_offer]

      if @job_offer.save
        redirect_to fve_job_offers_path, notice: 'Annonce publiée avec succès ! 🚀'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize [:fve, @job_offer]
    end

    def update
      authorize [:fve, @job_offer]
      if @job_offer.update(job_offer_params)
        redirect_to fve_job_offer_path(@job_offer), notice: 'Annonce mise à jour !'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # --- ACTIONS DE GESTION STATUT ---

    def toggle_status
      authorize [:fve, @job_offer], :update?

      # Si archivée ou brouillon -> Publier
      # Si publiée -> Brouillon
      # Si suspendue -> Publier
      new_status = (@job_offer.status == 'published') ? 'draft' : 'published'

      if @job_offer.update(status: new_status)
        msg = new_status == 'published' ? 'Annonce remise en ligne !' : 'Annonce retirée de la liste publique.'
        redirect_to fve_job_offer_path(@job_offer), notice: msg
      else
        redirect_to fve_job_offer_path(@job_offer), alert: "Action impossible."
      end
    end

    # --- ACTIONS CANDIDATS ---

    def accept_candidate
      authorize [:fve, @job_offer], :accept_candidate?
      application = @job_offer.job_applications.find(params[:application_id])

      service = RecruitMerchService.new(application)

      if service.call
        redirect_to fve_job_offer_path(@job_offer), notice: "Candidat recruté ! Contrat généré."
      else
        redirect_to fve_job_offer_path(@job_offer), alert: service.error_message
      end
    end

    def cancel_candidate
      authorize [:fve, @job_offer], :accept_candidate?
      application = @job_offer.job_applications.find(params[:application_id])

      contract = Contract.find_by(merch_id: application.merch_id, fve_id: current_user.id)

      ActiveRecord::Base.transaction do
        if contract
          WorkSession.where(
            contract: contract,
            start_time: @job_offer.start_date.beginning_of_day..@job_offer.end_date.end_of_day
          ).destroy_all
        end
        application.update!(status: 'pending')
      end

      redirect_to fve_job_offer_path(@job_offer), notice: "Recrutement annulé."
    rescue StandardError => e
      redirect_to fve_job_offer_path(@job_offer), alert: "Erreur : #{e.message}"
    end

    def reject_candidate
      authorize [:fve, @job_offer], :reject_candidate?
      @application = @job_offer.job_applications.find(params[:application_id])

      if @application.update(status: 'rejected')
        redirect_to fve_job_offer_path(@job_offer), notice: 'Candidature refusée.', status: :see_other
      else
        redirect_to fve_job_offer_path(@job_offer), alert: "Impossible de modifier le statut.", status: :see_other
      end
    end

    def destroy
      authorize [:fve, @job_offer]

      # On utilise l'update vers 'archived' car c'est défini dans ton modèle
      if @job_offer.update(status: 'archived')
        redirect_to fve_job_offers_path, notice: 'Annonce archivée. (Retrouvez-la via le filtre Statut)', status: :see_other
      else
        redirect_to fve_job_offers_path, alert: "Erreur lors de l'archivage.", status: :see_other
      end
    end

    private

    def set_job_offer
      @job_offer = JobOffer.find(params[:id])
    end

    def verify_fve
      unless current_user&.fve?
        redirect_to root_path, alert: 'Accès réservé aux recruteurs.'
      end
    end

    def job_offer_params
      params.require(:job_offer).permit(
        :title, :description, :mission_type, :contract_type,
        :start_date, :end_date, :break_start_time, :break_end_time,
        :company_name, :store_name, :address, :zipcode, :city, :department_code,
        :hourly_rate, :night_rate, :km_rate, :km_limit, :km_unlimited,
        :headcount_required, :ifm_rate, :cp_rate,
        :contact_email, :contact_phone,
        job_offer_slots_attributes: [
          :id,
          :date,
          :start_time,
          :end_time,
          :break_start_time,
          :break_end_time,
          :_destroy
        ]
      )
    end
  end
end
