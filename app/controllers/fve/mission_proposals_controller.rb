module Fve
  class MissionProposalsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_fve!
    before_action :set_proposal, only: [:destroy]

    # =========================================================
    # INDEX (Suivi des propositions)
    # =========================================================
    def index
      # 1. Configuration de la date (pour la navigation mois par mois si besoin)
      @year = (params[:year] || Date.current.year).to_i
      @month = (params[:month] || Date.current.month).to_i

      begin
        @target_date = Date.new(@year, @month, 1)
      rescue ArgumentError
        @target_date = Date.current.beginning_of_month
      end

      # Variables de navigation
      @prev_date = @target_date - 1.month
      @next_date = @target_date + 1.month

      # 2. Base de la requête (Tout ce que le FVE a envoyé)
      # On utilise .includes pour charger les infos du merch et ses settings d'un coup (Performance)
      @proposals = current_user.sent_mission_proposals
                               .includes(merch: :merch_setting)
                               .order(date: :desc, created_at: :desc)

      # 3. APPLICATION DES FILTRES (Logique cumulative)

      # A. Filtre venant du Dashboard (ex: 'today', 'upcoming')
      if params[:date_filter] == 'today'
        @proposals = @proposals.where(date: Date.today)
      elsif params[:date_filter] == 'upcoming'
        @proposals = @proposals.where('date >= ?', Date.today)
      end

      # B. Filtre de Statut (ex: 'accepted' depuis le dashboard)
      if params[:status_filter].present?
        @proposals = @proposals.where(status: params[:status_filter])
      end

      # C. Autres filtres (Recherche, Entreprise, Dates manuelles)
      @proposals = @proposals.search_by_merch_name(params[:query]) if params[:query].present?
      @proposals = @proposals.by_company(params[:company])         if params[:company].present?
      @proposals = @proposals.by_merch_preference(params[:preference]) if params[:preference].present?

      if params[:start_date].present? || params[:end_date].present?
        @proposals = @proposals.by_date_range(params[:start_date], params[:end_date])
      end

      # 4. SÉPARATION POUR L'AFFICHAGE (Onglets)
      # On s'assure que la valeur par défaut est un statut valide pour les onglets.
      @active_tab = params[:status_filter].presence || 'pending'

      # Si on filtre par "Accepted", @pending_proposals sera vide. C'est le comportement attendu.
      @pending_proposals   = @proposals.select(&:pending?)
      @accepted_proposals  = @proposals.select(&:accepted?)
      # Historique = Refusés ou Annulés
      @history_proposals   = @proposals.select { |p| p.declined? || p.cancelled? }
    end

    # =========================================================
    # CREATE (Nouvelle proposition)
    # =========================================================
    def create
      @proposal = MissionProposal.new(proposal_params)
      @proposal.fve = current_user
      @proposal.agency = current_user.agency

      # Récupération sécurisée du Merch
      @merch_user = User.find_by(id: @proposal.merch_id)

      unless @merch_user
        return redirect_back fallback_location: fve_merch_index_path, alert: 'Prestataire cible introuvable.'
      end

      # Vérification Contrat (Règle métier)
      unless @merch_user.contracts.exists?(agency: current_user.agency)
        return redirect_back fallback_location: fve_merch_path(@merch_user),
                             alert: "Impossible : #{@merch_user.firstname} n'a pas de contrat actif avec #{current_user.agency}."
      end

      if @proposal.save
        # Redirection vers le planning à la date de la mission pour voir le résultat
        redirect_to fve_planning_path(@merch_user, year: @proposal.date.year, month: @proposal.date.month),
                    notice: "Mission proposée avec succès à #{@merch_user.firstname} !"
      else
        redirect_back fallback_location: fve_merch_path(@merch_user),
                      alert: "Erreur : #{@proposal.errors.full_messages.to_sentence}"
      end
    end

    # =========================================================
    # DESTROY (Annulation / Suppression)
    # =========================================================
    def destroy
      merch_name = @proposal.merch.try(:full_name) || "Le prestataire"

      # On stocke la date pour la redirection avant de supprimer
      redirect_date = @proposal.date

      @proposal.destroy

      redirect_to fve_mission_proposals_path(year: redirect_date.year, month: redirect_date.month),
                  notice: "Proposition pour #{merch_name} supprimée."
    end

    private

    # Vérification des droits d'accès
    def require_fve!
      unless current_user&.fve?
        redirect_to root_path, alert: 'Accès réservé aux forces de vente.'
      end
    end

    # Récupération de la proposition (sécurisée au scope de l'utilisateur)
    def set_proposal
      @proposal = current_user.sent_mission_proposals.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to fve_mission_proposals_path, alert: "Proposition introuvable ou vous n'avez pas les droits."
    end

    # Strong Params
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
