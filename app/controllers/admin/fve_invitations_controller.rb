class Admin::FveInvitationsController < ApplicationController
  before_action :authenticate_user!
  before_action :verify_admin
  before_action :set_invitation, only: %i[destroy]

  def index
    @invitations = FveInvitation.order(created_at: :desc)
  end

  def new
    @invitation = FveInvitation.new
  end

  def create
    @invitation = FveInvitation.new(invitation_params)
    @invitation.token = SecureRandom.hex(20)
    @invitation.expires_at = 7.days.from_now

    if @invitation.save
      redirect_to admin_fve_invitations_path, notice: "Invitation FVE créée."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @invitation.destroy
    redirect_to admin_fve_invitations_path, notice: "Invitation supprimée."
  end

  private

  def set_invitation
    @invitation = FveInvitation.find(params[:id])
  end

  def verify_admin
    redirect_to root_path, alert: "Accès interdit" unless current_user&.admin?
  end

  def invitation_params
    params.require(:fve_invitation).permit(:email, :premium, :agency)
  end
end
