class Admin::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :verify_admin
  before_action :set_user, only: %i[show edit update destroy toggle_premium]

  # GET /admin/users
  def index
    authorize [:admin, User]

    if params[:query].present?
      query = params[:query].downcase
      search_pattern = "%#{query}%"

      # 1. Gestion intelligente des Rôles (Enum)
      # On regarde si le texte tapé correspond à un rôle (ex: "adm" correspond à "admin" -> 0)
      # User.roles renvoie un hash {"admin" => 0, "fve" => 1, ...}
      matching_roles = User.roles.select { |name, _val| name.include?(query) }.values

      # 2. Construction de la requête
      # On commence par les champs TEXTE classiques
      sql_query = "LOWER(firstname) LIKE :search OR
                   LOWER(lastname) LIKE :search OR
                   LOWER(email) LIKE :search OR
                   CAST(id AS TEXT) LIKE :search" # Recherche sur l'ID converti en texte

      # 3. Si on a trouvé des rôles correspondants, on ajoute la condition sur l'entier
      if matching_roles.any?
        sql_query += " OR role IN (:role_ids)"
      end

      # 4. Exécution de la requête
      @users = User.where(sql_query, search: search_pattern, role_ids: matching_roles).order(:firstname)

    else
      # Pas de recherche : on affiche tout
      @users = User.order(:firstname)
    end
  end

  # ... Le reste du contrôleur (show, edit, etc.) reste identique ...
  # (Assurez-vous de garder les autres méthodes en dessous)

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
    authorize [:admin, @user], :export_data? # Ligne Pundit corrigée

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

  def user_params
    params.require(:user).permit(
      :firstname, :lastname, :email, :phone_number,
      :allow_email, :allow_phone, :allow_identity
    )
  end
end
