class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    @user = current_user

    # --- Données du mois en cours ---
    @total_hours_month      = @user.total_hours_this_month
    @total_brut_month       = @user.total_brut_this_month
    @net_estimated_month    = @user.net_estimated_this_month
    @net_total_estimated_month = @user.net_total_estimated_this_month
    @km_month               = @user.total_km_this_month
    @km_payment_month       = @user.total_km_payment_this_month

    # Répartition par agence (mois)
    @by_agency = @user.total_by_agency_this_month
  end

  def update_privacy
    if current_user.update(user_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to dashboard_path, notice: 'Modifié' }
      end
    else
      render :index, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:allow_email, :allow_phone, :allow_identity)
  end
end
