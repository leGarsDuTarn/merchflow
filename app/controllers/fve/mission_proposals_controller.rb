class Fve::MissionProposalsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_fve!

  def create
    @merch = User.find(params[:merch_id])

    # 🔒 SÉCURITÉ CRITIQUE 🔒
    # On vérifie qu'un contrat existe déjà entre l'agence du FVE et le Merch
    # Si non, on bloque l'action immédiatement.
    unless @merch.has_contract_with_fve?(current_user)
      redirect_back fallback_location: fve_planning_path(@merch),
                    alert: "Action refusée : Vous n'avez pas de contrat actif avec ce merchandiser."
      return
    end

    # Création de la proposition
    @proposal = MissionProposal.new(proposal_params)
    @proposal.fve = current_user
    @proposal.merch = @merch

    # On impose l'agence du FVE (pour l'historique et la cohérence)
    @proposal.agency = current_user.agency

    # Statut initial
    @proposal.status = :pending

    if @proposal.save
      # TODO: Ajouter ici l'envoi de notification (SMS/Email) au Merch
      # NotificationService.notify_new_proposal(@proposal)

      redirect_to fve_planning_path(@merch), notice: 'Proposition envoyée avec succès ! En attente de la réponse du Merch.'
    else
      redirect_to fve_planning_path(@merch), alert: "Erreur lors de la proposition : #{@proposal.errors.full_messages.join(', ')}"
    end
  end

  private

  def require_fve!
    redirect_to root_path, alert: 'Accès réservé aux FVE' unless current_user&.fve?
  end

  def proposal_params
    params.require(:mission_proposal).permit(
      :date,
      :start_time,
      :end_time,
      :company,
      :store_name,
      :store_address,
      :hourly_rate,
      :message
    )
  end
end
