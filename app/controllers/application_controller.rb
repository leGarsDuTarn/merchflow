class ApplicationController < ActionController::Base
  include Pagy::Backend

  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [
      :firstname,
      :lastname,
      :username,
      :address,
      :zipcode,
      :city
    ])

    devise_parameter_sanitizer.permit(:account_update, keys: [
      :firstname,
      :lastname,
      :username,
      :address,
      :zipcode,
      :city
    ])
  end
end
