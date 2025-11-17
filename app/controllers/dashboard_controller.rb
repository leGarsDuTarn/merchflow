class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @user = current_user

    # Résumé global
    @total_hours   = @user.total_hours_worked
    @total_brut    = @user.total_brut
    @total_ifm_cp  = @user.total_ifm_cp
    @total_km      = @user.total_km
    @total_km_pay  = @user.total_km_payment

    # Statistiques par employeur
    @by_agency = @user.total_by_agency
  end
end
