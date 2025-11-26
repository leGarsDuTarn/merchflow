class Admin::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :verify_admin
  before_action :set_user, only: %i[show edit update destroy toggle_premium]

  # GET /admin/users
  def index
    @users = User.order(:firstname)
  end

  # GET /admin/users/:id
  def show; end

  # GET /admin/users/:id/edit
  def edit; end

  # PATCH /admin/users/:id
  def update
    if @user.update(user_params)
      redirect_to admin_user_path(@user), notice: 'Utilisateur mis à jour avec succès.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/users/:id
  def destroy
    if @user == current_user
      redirect_back fallback_location: admin_users_path,
                    alert: 'Vous ne pouvez pas supprimer votre propre compte admin.'
      return
    end

    @user.destroy
    redirect_to admin_users_path, notice: 'Utilisateur supprimé.'
  end

  # PATCH /admin/users/:id/toggle_premium
  def toggle_premium
    @user.update(premium: !@user.premium?)

    redirect_back fallback_location: admin_users_path,
                  notice: "Premium #{@user.premium? ? 'activé' : 'désactivé'} pour #{@user.username}."
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def verify_admin
    redirect_to root_path, alert: 'Accès interdit.' unless current_user&.admin?
  end

  def user_params
    params.require(:user).permit(
      :firstname, :lastname, :email, :phone_number,
      :allow_email, :allow_phone, :allow_identity
    )
  end
end
