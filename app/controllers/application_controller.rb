class ApplicationController < ActionController::Base
  include Pagy::Backend
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_merch_notifications, if: :current_user_is_merch?

  # Rendre les méthodes de garde disponibles dans les vues si nécessaire
  helper_method :is_admin?
  helper_method :is_fve?

  def after_sign_out_path_for(_resource_or_scope)
    root_path
  end

  def after_sign_in_path_for(resource)
    if resource.admin?
      admin_dashboard_path
    elsif resource.fve?
      fve_dashboard_path
    else
      dashboard_path # merch
    end
  end

  def after_sign_up_path_for(resource)
    if resource.admin?
      admin_dashboard_path
    elsif resource.fve?
      fve_dashboard_path
    else
      dashboard_path
    end
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[
      firstname
      lastname
      username
      address
      zipcode
      city
    ])

    devise_parameter_sanitizer.permit(:account_update, keys: %i[
      firstname
      lastname
      username
      address
      zipcode
      city
      phone_number
    ])
  end

  # ============================================================
  # 🔒 MÉTHODES DE GARDE (Sécurité)
  # ============================================================

  # Vérifie si l'utilisateur est un administrateur.
  def require_admin
    unless current_user&.admin?
      redirect_to root_path, alert: 'Accès non autorisé : Réservé aux administrateurs.'
    end
  end

  # Vérifie si l'utilisateur est FVE (peut être utilisé par d'autres contrôleurs FVE)
  def require_fve
    unless current_user&.fve? || current_user&.admin?
      redirect_to root_path, alert: 'Accès non autorisé : Réservé aux forces de vente.'
    end
  end

  # Helpers pour vérifier le rôle dans les vues
  def is_admin?
    current_user&.admin?
  end

  def is_fve?
    current_user&.fve?
  end


  private

  def user_not_authorized
    redirect_to root_path, alert: 'Accès non autorisé.'
  end

  def current_user_is_merch?
    user_signed_in? && current_user.merch?
  end

  def set_merch_notifications
    @pending_proposals_count = current_user.received_mission_proposals
                                           .where(status: :pending)
                                           .count
  end
end
