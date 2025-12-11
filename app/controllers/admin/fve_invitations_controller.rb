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

      # 1. GÉNÉRATION DU LIEN (Pour le copier-coller Admin)
      # Note : On utilise fve_accept_invitation_url car la route est dans le namespace :fve
      invite_link = fve_accept_invitation_url(token: @invitation.token)

      # 2. LOGIQUE D'ENVOI D'EMAIL (Seulement en DEV pour l'instant)
      # Permet de garder la logique de récupération du Label Agence
      agency_label = Agency.find_by(code: @invitation.agency)&.label || @invitation.agency.to_s.humanize

      if Rails.env.development?
        # En Dev, ca envoie le mail pour tester le design via Letter Opener
        FveInvitationMailer.invite_fve(@invitation, agency_label).deliver_now
      end

      # 3. MESSAGE FLASH AVEC LE LIEN
      # L'input permet de copier le lien facilement même en Prod sans SMTP
      flash[:notice] = "Invitation FVE créée !<br>
                        <small>Copiez ce lien et envoyez-le manuellement :</small><br>
                        <input type='text' value='#{invite_link}' class='form-control mt-2' readonly onclick='this.select();'>".html_safe

      redirect_to admin_fve_invitations_path
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
