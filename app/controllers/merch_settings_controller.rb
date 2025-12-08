class MerchSettingsController < ApplicationController
  # Sécurité : connexion requise
  before_action :authenticate_user!

  # Chargement du modèle pour toutes les actions
  before_action :set_merch_setting

  # GET /settings/merch
  def show
    # @merch_setting est disponible
  end

  # PATCH/PUT /settings/merch (Formulaire principal)
  def update
    if @merch_setting.update(merch_setting_params)
      redirect_to merch_settings_path, notice: 'Vos préférences générales ont été enregistrées.'
    else
      render :show, status: :unprocessable_entity
    end
  end

  # ==========================================================
  # ACTIONS TOGGLES (AJAX COMPATIBLE)
  # ==========================================================

  # Note : J'utilise une méthode privée 'respond_with_toggle' (voir plus bas)
  # pour éviter de répéter le bloc 'respond_to' à chaque fois.

  def toggle_identity
    @merch_setting.toggle_identity!
    respond_with_toggle("Visibilité de l'identité modifiée.")
  end

  def toggle_share_address
    @merch_setting.toggle_share_address!
    respond_with_toggle("Partage de l'adresse modifié.")
  end

  def toggle_share_planning
    @merch_setting.toggle_share_planning!
    respond_with_toggle("Partage du planning modifié.")
  end

  def toggle_allow_email
    @merch_setting.toggle_allow_email!
    respond_with_toggle("Contact par email modifié.")
  end

  def toggle_allow_phone
    @merch_setting.toggle_allow_phone!
    respond_with_toggle("Contact par téléphone modifié.")
  end

  def toggle_allow_message
    @merch_setting.toggle_allow_message!
    respond_with_toggle("Contact par message modifié.")
  end

  def toggle_accept_mission_proposals
    @merch_setting.toggle_accept_mission_proposals!
    respond_with_toggle("Acceptation des missions modifiée.")
  end

  def toggle_role_merch
    @merch_setting.toggle_role_merch!
    respond_with_toggle("Rôle Merchandising modifié.")
  end

  def toggle_role_anim
    @merch_setting.toggle_role_anim!
    respond_with_toggle("Rôle Animation modifié.")
  end

  private

  # Trouve ou crée les paramètres de l'utilisateur
  def set_merch_setting
    @merch_setting = current_user.merch_setting || current_user.create_merch_setting!
  end

  # Strong Parameters
  def merch_setting_params
    params.require(:merch_setting).permit(
      :preferred_contact_channel,
      :accept_mission_proposals,
      # Les autres champs ne sont techniquement pas nécessaires ici
      # car gérés par les toggles, mais on peut les laisser par sécurité.
      :allow_identity, :share_address, :share_planning,
      :allow_contact_email, :allow_contact_phone, :allow_contact_message,
      :role_anim, :role_merch
    )
  end

  # --- MÉTHODE MAGIQUE POUR LE "SANS RECHARGEMENT" ---
  # Cette méthode gère la réponse pour toutes les actions toggle ci-dessus.
  def respond_with_toggle(message)
    respond_to do |format|
      # Format HTML (Fallback classique si JS désactivé)
      format.html { redirect_to merch_settings_path, notice: message }

      # Format JSON (Pour Stimulus / AJAX) -> Renvoie juste un code 200 OK
      format.json { head :ok }
    end
  end
end
