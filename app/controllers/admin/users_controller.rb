class Admin::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :verify_admin
  before_action :set_user, only: %i[show edit update destroy toggle_premium]

  # GET /admin/users
  def index
    authorize [:admin, User]
    @users = User.order(:firstname)
  end

  # GET /admin/users/:id
  def show
    authorize [:admin, @user]
  end

  # GET /admin/users/:id/edit
  def edit
    authorize [:admin, @user]
  end

  # PATCH /admin/users/:id
  def update
    authorize [:admin, @user]
    if @user.update(user_params)
      redirect_to admin_user_path(@user), notice: 'Utilisateur mis à jour avec succès.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /admin/users/:id
  def destroy
    authorize [:admin, @user]
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
    authorize [:admin, @user]
    @user.update(premium: !@user.premium?)

    redirect_back fallback_location: admin_users_path,
                  notice: "Premium #{@user.premium? ? 'activé' : 'désactivé'} pour #{@user.username}."
  end

  def export_data
    @user = User.find(params[:id])

    # Définition du nom de fichier
    filename = "donnees_utilisateur_#{@user.lastname.downcase}_#{@user.id}.pdf"

    # Wicked PDF rend le PDF basé sur une vue spéciale
    render pdf: filename,
           template: 'admin/users/export_data_pdf', # Vue à créer ci-dessous
           layout: 'pdf' # Assurez-vous d'avoir un layout 'pdf.html.erb' simple (voir documentation Wicked PDF)
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
