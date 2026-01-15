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
      invite_link = fve_accept_invitation_url(token: @invitation.token)
      agency_label = Agency.find_by(code: @invitation.agency)&.label || @invitation.agency.to_s.humanize

      # Envoi du mail (prod & dev)
      FveInvitationMailer.invite_fve(@invitation, agency_label).deliver_now

      flash[:notice] = "Invitation FVE créée et email envoyé !<br>
                      <small>Lien de secours :</small><br>
                      <input type='text' value='#{invite_link}' class='form-control mt-2' readonly onclick='this.select();'>".html_safe

      redirect_to admin_fve_invitations_path, status: :see_other
    else
      # C'est bien de garder unprocessable_entity ici pour que Turbo affiche les erreurs
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
