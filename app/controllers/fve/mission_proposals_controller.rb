# app/controllers/fve/mission_proposals_controller.rb
module Fve
  class MissionProposalsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_fve!
    # On charge la proposition pour l'action destroy
    before_action :set_proposal, only: [:destroy]

    # =========================================================
    # INDEX (Suivi des propositions envoyées)
    # =========================================================
    def index
      # 1. Gestion de la date (Navigation par mois)
      @year = (params[:year] || Date.current.year).to_i
      @month = (params[:month] || Date.current.month).to_i

      begin
        @target_date = Date.new(@year, @month, 1)
      rescue ArgumentError
        @target_date = Date.current.beginning_of_month
      end

      # 2. Récupération des propositions du mois choisi
      @proposals = current_user.sent_mission_proposals
                               .for_month(@target_date) # 👈 Scope par mois
                               .includes(:merch)
                               .order(date: :desc, created_at: :desc)

      # 3. Séparation pour les onglets
      @pending_proposals   = @proposals.select(&:pending?)
      @accepted_proposals  = @proposals.select(&:accepted?)
      # On regroupe refusées et annulées
      @history_proposals   = @proposals.select { |p| p.declined? || p.cancelled? }

      # Variables pour la navigation (Mois suivant / Précédent)
      @prev_date = @target_date - 1.month
      @next_date = @target_date + 1.month
    end

    # =========================================================
    # CREATE (Envoi d'une nouvelle proposition)
    # =========================================================
    def create
      # 1. Instanciation, assignation FVE et Agence
      @proposal = MissionProposal.new(proposal_params)
      @proposal.fve = current_user
      @proposal.agency = current_user.agency

      # 2. Vérification de l'existence du prestataire (pour les messages d'erreur)
      @merch_user = User.find_by(id: @proposal.merch_id)
      unless @merch_user
        return redirect_back fallback_location: fve_merch_index_path, alert: 'Prestataire cible introuvable.'
      end

      # 3. Vérification du contrat (Contrainte métier)
      unless @merch_user.contracts.exists?(agency: current_user.agency)
        return redirect_back fallback_location: fve_merch_path(@merch_user),
                             alert: "Action refusée : Le prestataire doit avoir un contrat actif avec votre agence (#{current_user.agency.capitalize})."
      end

      # 4. Sauvegarde
      # Le statut est automatiquement :pending (par défaut dans le modèle)
      # Les validations du modèle gèrent : alignement des dates, chevauchement avec PROPOSALS et WORK_SESSIONS.
      if @proposal.save
        # TODO: Ajouter ici l'envoi de notification (SMS/Email) au Merch
        redirect_to fve_planning_path(@merch_user, year: @proposal.date.year, month: @proposal.date.month),
                    notice: "Proposition envoyée avec succès à #{@merch_user.firstname} !"
      else
        # Si les validations du modèle échouent (chevauchement, champs manquants...)
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

    # Chargement de la proposition pour destroy
    def set_proposal
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
