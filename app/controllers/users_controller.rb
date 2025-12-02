# app/controllers/users_controller.rb
class UsersController < ApplicationController
  before_action :authenticate_user! # Assure que seul un utilisateur connecté peut y accéder

  def show
    # Ce contrôleur n'a pas pour vocation d'afficher un profil.
    # Il sert uniquement de point de redirection de secours pour Devise.

    # Rediriger immédiatement l'utilisateur vers son tableau de bord approprié
    if current_user.admin?
      redirect_to admin_dashboard_path
    elsif current_user.fve?
      redirect_to fve_dashboard_path
    else
      redirect_to dashboard_path # Merch
    end
  end
end
