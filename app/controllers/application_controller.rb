class ApplicationController < ActionController::Base
  include Pagy::Backend
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :set_merch_notifications, if: :current_user_is_merch?

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

  private

  def user_not_authorized
    redirect_to root_path, alert: 'Accès non autorisé.'
  end

  def current_user_is_merch?
    # Vérifie si l'utilisateur est connecté et a le rôle merch
    user_signed_in? && current_user.merch?
  end

  def set_merch_notifications
    # Calcule le nombre de propositions reçues et en attente
    # La variable @pending_proposals_count est utilisée dans la navbar.
    @pending_proposals_count = current_user.received_mission_proposals
                                           .where(status: :pending)
                                           .count
  end
end
