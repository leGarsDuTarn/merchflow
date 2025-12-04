# app/controllers/proposals_controller.rb
class ProposalsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_proposal, only: %i[update destroy] # Ajout d'un before_action

  def index
    # ==========================================================
    # 1. LOGIQUE DE NAVIGATION MENSUELLE
    # ==========================================================
    @year = (params[:year] || Date.current.year).to_i
    @month = (params[:month] || Date.current.month).to_i

    begin
      @target_date = Date.new(@year, @month, 1)
    rescue ArgumentError
      @target_date = Date.current.beginning_of_month
    end

    start_date = @target_date.beginning_of_month
    end_date = @target_date.end_of_month

    @status_filter = params[:status] # Statut actuel (ex: 'pending', 'accepted')

    # ==========================================================
    # 2. RÉCUPÉRATION ET FILTRAGE DES DONNÉES
    # ==========================================================
    proposals_scope = current_user.received_mission_proposals
                                  .where(date: start_date..end_date)

    # Retire toutes les missions passées (quel que soit le statut)
    proposals_scope = proposals_scope.active_opportunities

    # Filtrer par statut si le paramètre est fourni et valide
    if @status_filter.present? && MissionProposal.statuses.key?(@status_filter)
      proposals_scope = proposals_scope.where(status: @status_filter)
    end

    @proposals = proposals_scope.order(date: :asc, created_at: :desc)

    # --- Variables de navigation pour la vue ---
    @prev_month = (@target_date - 1.month).month
    @prev_year = (@target_date - 1.month).year
    @next_month = (@target_date + 1.month).month
    @next_year = (@target_date + 1.month).year
  end

  def update
    # L'action gère l'Acceptation ou le Refus
    if params[:mission_proposal][:status] == 'accepted'
      # On utilise la méthode transactionnelle accept! du modèle
      if @proposal.accept!
        redirect_to merch_proposals_path, notice: "Proposition de mission de #{@proposal.fve.agency_label} acceptée ! La mission a été ajoutée à votre planning."
      else
        # Affiche les erreurs du modèle (ex: contrat non trouvé)
        redirect_to merch_proposals_path, alert: "Erreur lors de l'acceptation : #{@proposal.errors.full_messages.to_sentence}"
      end
    elsif params[:mission_proposal][:status] == 'declined'
      if @proposal.update(status: :declined)
        redirect_to merch_proposals_path, notice: "Proposition de mission de #{@proposal.fve.agency_label} refusée."
      else
        redirect_to merch_proposals_path, alert: 'Erreur lors du refus.'
      end
    else
      redirect_to merch_proposals_path, alert: 'Action non valide.'
    end
  end

  def destroy
    proposal_title = @proposal.company.presence || @proposal.fve&.agency_label || "Proposition (ID: #{@proposal.id})"

    # La suppression de la proposition n'affecte PAS la WorkSession déjà créée
    if @proposal.destroy
      redirect_to merch_proposals_path, notice: "La proposition de #{proposal_title} a été définitivement supprimée de votre liste d'opportunités."
    else
      redirect_to merch_proposals_path, alert: "Erreur lors de la suppression de la proposition."
    end
  end

  private

  def set_proposal
    # Récupère la proposition uniquement si elle est adressée à l'utilisateur Merch courant
    @proposal = current_user.received_mission_proposals.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to merch_proposals_path, alert: 'Proposition introuvable.'
  end
end
