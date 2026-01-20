class Admin::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :verify_admin
  before_action :set_user, only: %i[show edit update destroy toggle_premium export_data]

  # GET /admin/users
  def index
    authorize [:admin, User]

    # 1. Utilisation du scope pour charger les stats de missions (Optimisé)
    @users = User.with_mission_stats

    # 2. Utilisation du scope de recherche si paramètre présent
    @users = @users.search_admin(params[:query]) if params[:query].present?

    # 3. Application du Tri
    case params[:sort]
    when 'date_asc'
      @users = @users.order(created_at: :asc)
    when 'missions_desc'
      # Tri basé sur l'attribut calculé par le scope 'with_mission_stats'
      @users = @users.order('missions_count DESC')
    when 'missions_asc'
      @users = @users.order('missions_count ASC')
    else
      # Défaut : "date_desc" (Les plus récents en premier)
      @users = @users.order(created_at: :desc)
    end
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
    authorize [:admin, @user] # Modification pour utiliser l'instance @user déjà settée

    # 1. Création de l'instance du PDF avec Prawn
    pdf = UserPdf.new(@user)

    # 2. Envoi du fichier généré (binaire)
    send_data pdf.render,
              filename: "donnees_rgpd_#{@user.lastname.downcase}_#{@user.id}.pdf",
              type: "application/pdf",
              disposition: "attachment" # Force le téléchargement du fichier
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def verify_admin
    redirect_to root_path, alert: 'Accès interdit.' unless current_user&.admin?
  end
end
