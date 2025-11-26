class Fve::InvitationsController < ApplicationController

  def show
    @invitation = FveInvitation.find_by(token: params[:token])

    if @invitation.nil? || @invitation.expired? || @invitation.used?
      redirect_to root_path, alert: 'Invitation invalide ou expirée.'
    end
  end

  def create
    @invitation = FveInvitation.find_by(token: params[:token])

    if @invitation.nil? || @invitation.used?
      redirect_to root_path, alert: 'Invitation invalide.'
      return
    end

    # Création du compte FVE
    user = User.new(
      email: @invitation.email,
      password: params[:password],
      role: :fve,
      premium: @invitation.premium
    )

    if user.save
      @invitation.update(used: true)
      redirect_to new_user_session_path, notice: 'Compte FVE créé !'
    else
      render :show, status: :unprocessable_entity
    end
  end
end
