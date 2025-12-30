class Users::PasswordsController < Devise::PasswordsController
  protected

  # Cette méthode est appelée juste après que l'utilisateur a cliqué sur "Envoyer les instructions"
  def after_sending_reset_password_instructions_path_for(resource_name)
    # On redirige tout le monde (Merch, Admin, FVE) vers la page de connexion principale
    new_user_session_path
  end
end
