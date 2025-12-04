# app/controllers/proposals_controller.rb
class ProposalsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_proposal, only: [:update] # Ajout d'un before_action

  def index
    @proposals = current_user.received_mission_proposals
                             .where(status: :pending)
                             .order(created_at: :desc)
  end

  def update
    # L'action gère l'Acceptation ou le Refus
    if params[:status] == 'accepted'
      if @proposal.update(status: :accepted)
        # TODO: Logique additionnelle si la mission est acceptée (ex: créer un contrat/session)
        redirect_to merch_proposals_path, notice: "Proposition de mission de #{@proposal.fve.agency_label} acceptée !"
      else
        redirect_to merch_proposals_path, alert: "Erreur lors de l'acceptation."
      end
    elsif params[:status] == 'declined'
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
