class Admin::FveInvitationsController < ApplicationController
  before_action :authenticate_user!
  before_action :verify_admin
  before_action :set_invitation, only: %i[destroy]

  def index
    authorize [:admin, FveInvitation]
    @invitations = FveInvitation.order(created_at: :desc)
  end

  def new
    @invitation = FveInvitation.new
    authorize [:admin, @invitation]
  end

  def create
    @invitation = FveInvitation.new(invitation_params)
    authorize [:admin, @invitation]

    # Génération manuelle du token et de l'expiration
    @invitation.token = SecureRandom.hex(20)
    @invitation.expires_at = 7.days.from_now

    if @invitation.save

      # CORRECTION CRITIQUE ICI : Récupération dynamique du Label de l'Agence
      # On cherche le label dans la table Agencies à partir du code stocké dans l'invitation.
      agency_label = Agency.find_by(code: @invitation.agency)&.label || @invitation.agency.to_s.humanize

      # L'appel à la classe de mailer doit être mis à jour pour prendre le label en paramètre
      # NOTE: Si FveInvitationMailer.invite_fve n'accepte pas agency_label,
      # vous devrez modifier la classe Mailer pour qu'elle utilise @invitation et agency_label.
      FveInvitationMailer.invite_fve(@invitation, agency_label).deliver_now

      redirect_to admin_fve_invitations_path,
                  notice: "Invitation FVE créée et email envoyé à #{@invitation.email}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    authorize [:admin, @invitation]
    @invitation.destroy

    redirect_to admin_fve_invitations_path, notice: 'Invitation supprimée.'
  end

  private

  def set_invitation
    @invitation = FveInvitation.find(params[:id])
  end

  def verify_admin
    redirect_to root_path, alert: 'Accès interdit' unless current_user&.admin?
  end

  def invitation_params
    params.require(:fve_invitation).permit(:email, :premium, :agency)
  end
end
