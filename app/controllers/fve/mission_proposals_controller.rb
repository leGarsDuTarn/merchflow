# app/controllers/fve/mission_proposals_controller.rb
module Fve
  class MissionProposalsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_fve!
    before_action :set_proposal, only: [:destroy]

    # =========================================================
    # INDEX (Suivi des propositions envoyées)
    # =========================================================
    def index
      # 1. Gestion de la date de navigation (Mois/Année)
      @year = (params[:year] || Date.current.year).to_i
      @month = (params[:month] || Date.current.month).to_i

      begin
        @target_date = Date.new(@year, @month, 1)
      rescue ArgumentError
        @target_date = Date.current.beginning_of_month
      end

      # 2. Base de la requête (Toutes les propositions envoyées par ce FVE)
      @proposals = current_user.sent_mission_proposals
                               .includes(merch: :merch_setting)
                               .order(date: :desc, created_at: :desc)

      # 3. FILTRES DE RECHERCHE

      # Filtre : Nom/Pseudo du Merch
      if params[:query].present?
        @proposals = @proposals.search_by_merch_name(params[:query])
      end

      # Filtre : Compagnie
      if params[:company].present?
        @proposals = @proposals.by_company(params[:company])
      end

      # Filtre : Préférence (Merch/Anim)
      if params[:preference].present?
        @proposals = @proposals.by_merch_preference(params[:preference])
      end

      # Filtre : Plage de Dates 
      if params[:start_date].present? || params[:end_date].present?
        @proposals = @proposals.by_date_range(params[:start_date], params[:end_date])
      end


      # 4. Séparation pour les onglets
      @pending_proposals   = @proposals.select(&:pending?)
      @accepted_proposals  = @proposals.select(&:accepted?)
      @history_proposals   = @proposals.select { |p| p.declined? || p.cancelled? }

      # Variables pour la navigation
      @prev_date = @target_date - 1.month
      @next_date = @target_date + 1.month
    end

    # =========================================================
    # CREATE (Envoi d'une nouvelle proposition)
    # =========================================================
    def create
      @proposal = MissionProposal.new(proposal_params)
      @proposal.fve = current_user
      @proposal.agency = current_user.agency

      @merch_user = User.find_by(id: @proposal.merch_id)
      unless @merch_user
        return redirect_back fallback_location: fve_merch_index_path, alert: 'Prestataire cible introuvable.'
      end

      # Vérification du contrat (Contrainte métier : avant la validation finale)
      unless @merch_user.contracts.exists?(agency: current_user.agency)
        return redirect_back fallback_location: fve_merch_path(@merch_user),
                             alert: "Action refusée : Le prestataire doit avoir un contrat actif avec votre agence (#{current_user.agency.capitalize})."
      end

      # Sauvegarde (Le modèle gère le chevauchement et l'alignement des dates)
      if @proposal.save
        # TODO: Ajouter ici l'envoi de notification (SMS/Email) au Merch
        redirect_to fve_planning_path(@merch_user, year: @proposal.date.year, month: @proposal.date.month),
                    notice: "Proposition envoyée avec succès à #{@merch_user.firstname} !"
      else
        redirect_back fallback_location: fve_merch_path(@merch_user),
                      alert: "Erreur lors de la proposition : #{@proposal.errors.full_messages.to_sentence}"
      end
    end

    # =========================================================
    # DESTROY (Suppression sécurisée du suivi)
    # =========================================================
    def destroy
      merch_name = @proposal.merch.full_name

      # Suppression de la proposition (sans affecter la WorkSession si elle est acceptée)
      @proposal.destroy

      # Redirection vers la vue du mois concerné par la suppression
      redirect_to fve_mission_proposals_path(year: @proposal.date.year, month: @proposal.date.month),
                  notice: "La proposition pour #{merch_name} a été supprimée de votre suivi."
    end


    private

    def require_fve!
      redirect_to root_path, alert: 'Accès réservé aux FVE' unless current_user&.fve?
    end

    def set_proposal
      # Sécurité : on s'assure que la proposition appartient bien au FVE connecté
      @proposal = current_user.sent_mission_proposals.find(params[:id])
    end

    def proposal_params
      params.require(:mission_proposal).permit(
        :merch_id,
        :date,
        :start_time,
        :end_time,
        :company,
        :store_name,
        :store_address,
        :hourly_rate,
        :message,
        :effective_km
      )
    end
  end
end
