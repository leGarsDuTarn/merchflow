class Fve::InvitationsController < ApplicationController
  include Pundit::Authorization

  before_action :set_invitation, only: %i[accept complete]

  def accept
    authorize [:fve, :invitations], :accept?

    if @invitation.used?
      redirect_to root_path, alert: "Cette invitation a déjà été utilisée."
      return
    end

    if @invitation.expired?
      redirect_to root_path, alert: "Cette invitation a expiré."
      return
    end

    @user = User.new
  end

  def complete
    authorize [:fve, :invitations], :complete?

    @user = User.new(user_params)
    @user.role    = :fve
    @user.premium = @invitation.premium

    if @user.save
      @invitation.update(used: true)

      sign_in(@user)
      redirect_to fve_dashboard_path,
                  notice: "Votre compte FVE est maintenant actif. Bienvenue !"
    else
      render :accept, status: :unprocessable_entity
    end
  end

  private

  def set_invitation
    @invitation = FveInvitation.find_by(token: params[:token])

    unless @invitation
      redirect_to root_path, alert: "Invitation introuvable."
    end
  end

  def user_params
    params.require(:user).permit(
      :email,
      :password,
      :password_confirmation,
      :firstname,
      :lastname
    )
  end
end
