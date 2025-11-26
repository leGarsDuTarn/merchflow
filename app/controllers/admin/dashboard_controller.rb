class Admin::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def index
    # === STATISTIQUES GLOBALES ===
    @total_users        = User.count
    @total_merch        = User.merch.count
    @total_fve          = User.fve.count
    @total_premium_fve  = User.fve.where(premium: true).count
    @new_users_month    = User.where('created_at >= ?', Time.current.beginning_of_month).count

    # Invitations
    @invitations_total      = FveInvitation.count
    @invitations_used       = FveInvitation.where(used: true).count
    @invitations_unused     = FveInvitation.where(used: false).count
    @invitations_expired    = FveInvitation.where('expires_at < ?', Time.current).count

    # Activité des merch
    @work_sessions_month = WorkSession.where('date >= ?', Date.current.beginning_of_month).count
  end

  private

  def require_admin!
    unless current_user&.admin?

      redirect_to root_path, alert: "Accès réservé à l'administration."
    end
  end
end
