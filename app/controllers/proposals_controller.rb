# app/controllers/proposals_controller.rb
class ProposalsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_proposal, only: [:update] # Ajout d'un before_action

  def index
    # ==========================================================
    # LOGIQUE DE NAVIGATION MENSUELLE
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

    # --- Récupération des données filtrées ---
    proposals_scope = current_user.received_mission_proposals
                                  .where(date: start_date..end_date)
                                  .order(date: :asc, created_at: :desc)

    # Filtrer par statut si le paramètre est fourni et valide
    if @status_filter.present? && MissionProposal.statuses.key?(@status_filter)
      proposals_scope = proposals_scope.where(status: @status_filter)
    end

    @proposals = proposals_scope

    # --- Variables de navigation pour la vue ---
    @prev_month = (@target_date - 1.month).month
    @prev_year = (@target_date - 1.month).year
    @next_month = (@target_date + 1.month).month
    @next_year = (@target_date + 1.month).year
  end

  def update
    # L'action gère l'Acceptation ou le Refus
    if params[:mission_proposal][:status] == 'accepted' # On utilise params[:mission_proposal][:status] car button_to envoie des paramètres imbriqués
      if @proposal.update(status: :accepted)

        # 🚨 LOGIQUE CRITIQUE : Créer la WorkSession
        WorkSession.create_from_proposal(@proposal)

        redirect_to merch_proposals_path, notice: "Proposition de mission de #{@proposal.fve.agency_label} acceptée ! La mission a été ajoutée à votre planning."
      else
        redirect_to merch_proposals_path, alert: "Erreur lors de l'acceptation."
      end
    elsif params[:mission_proposal][:status] == 'declined'
      if @proposal.update(status: :declined)
        redirect_to merch_proposals_path, notice: "Proposition de mission de #{@proposal.fve.agency_label} refusée."
      else
        redirect_to merch_proposals_path, alert: 'Erreur lors du refus.'
      end
    else
      # Si le statut n'est pas reconnu
      redirect_to merch_proposals_path, alert: 'Action non valide.'
    end
  end

  private

  def set_proposal
    @proposal = current_user.received_mission_proposals.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to merch_proposals_path, alert: 'Proposition introuvable.'
  end
end
