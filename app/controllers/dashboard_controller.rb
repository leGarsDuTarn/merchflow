class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    if current_user.admin?
      redirect_to admin_dashboard_path and return
    elsif current_user.fve?
      redirect_to fve_dashboard_path and return
    end

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
    if current_user.update(privacy_params)
      head :ok # Statut 200 - succès
    else
      head :unprocessable_entity # Statut 422 - erreur
    end
  end

  private

  def privacy_params
    params.require(:user).permit(:allow_email, :allow_phone, :allow_identity)
  end
end
