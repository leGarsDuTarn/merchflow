class ApplicationController < ActionController::Base
  include Pagy::Backend
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  before_action :configure_permitted_parameters, if: :devise_controller?

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
      allow_email
      allow_phone
      allow_identity
    ])
  end

  private

  def user_not_authorized
    redirect_to root_path, alert: 'Accès non autorisé.'
  end
end
