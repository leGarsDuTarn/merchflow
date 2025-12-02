# app/controllers/merch_settings_controller.rb
class MerchSettingsController < ApplicationController
  # Assure que seul un utilisateur connecté peut accéder à ses paramètres
  before_action :authenticate_user!

  # Charge ou crée le MerchSetting de l'utilisateur courant pour toutes les actions
  before_action :set_merch_setting

  # GET /settings/merch
  # Affiche le formulaire de modification des paramètres
  def show
    # @merch_setting est disponible pour la vue
  end

  # PATCH/PUT /settings/merch
  # Met à jour les paramètres via un formulaire
  def update
    if @merch_setting.update(merch_setting_params)
      redirect_to merch_settings_path, notice: 'Vos paramètres de profil ont été mis à jour avec succès.'
    else
      # Si la validation échoue, rend la vue 'show' avec les erreurs
      render :show, status: :unprocessable_entity
    end
  end

  # ==========================================================
  # ACTIONS DE BASCULEMENT RAPIDE (TOGGLES)
  # ==========================================================

  # Visibilité de l'identité
  def toggle_identity
    @merch_setting.toggle_identity!
    redirect_to merch_settings_path, notice: 'Visibilité de l\'identité basculée.'
  end

  # Partage de l'adresse
  def toggle_share_address
    @merch_setting.toggle_share_address!
    redirect_to merch_settings_path, notice: 'Partage de l\'adresse basculé.'
  end

  # Autorisation de contact par email
  def toggle_allow_email
    @merch_setting.toggle_allow_email!
    redirect_to merch_settings_path, notice: 'Autorisation de contact par email basculée.'
  end

  # Autorisation de contact par téléphone
  def toggle_allow_phone
    @merch_setting.toggle_allow_phone!
    redirect_to merch_settings_path, notice: 'Autorisation de contact par téléphone basculée.'
  end

  # Autorisation de contact par message
  def toggle_allow_message
    @merch_setting.toggle_allow_message!
    redirect_to merch_settings_path, notice: 'Autorisation de contact par message basculée.'
  end

  # Accepte les propositions de missions
  def toggle_accept_mission_proposals
    @merch_setting.toggle_accept_mission_proposals!
    redirect_to merch_settings_path, notice: 'Acceptation des propositions de missions basculée.'
  end

  # Préférence : missions de Merchandising
  def toggle_role_merch
    @merch_setting.toggle_role_merch!
    redirect_to merch_settings_path, notice: 'Préférence Merchandising basculée.'
  end

  # Préférence : missions d'Animation
  def toggle_role_anim
    @merch_setting.toggle_role_anim!
    redirect_to merch_settings_path, notice: 'Préférence Animation basculée.'
  end

  private

  # Charge le MerchSetting existant ou le crée s'il n'existe pas
  def set_merch_setting
    @merch_setting = current_user.merch_setting || current_user.create_merch_setting!
  end

  # Paramètres autorisés (Strong Parameters)
  def merch_setting_params
    params.require(:merch_setting).permit(
      :allow_identity,
      :share_address,
      :share_planning,
      :allow_contact_email,
      :allow_contact_phone,
      :allow_contact_message,
      :allow_none,
      :preferred_contact_channel,
      :role_anim,
      :role_merch,
      :accept_mission_proposals
    )
  end
end
