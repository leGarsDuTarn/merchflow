class ApplicationController < ActionController::Base
  include Pagy::Backend
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  before_action :configure_permitted_parameters, if: :devise_controller?

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
