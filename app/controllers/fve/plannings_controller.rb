class Fve::PlanningsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_fve_or_admin!

  def show
    # Vérification Pundit
    authorize [:fve, :plannings], :show?

    # Le merch dont on veut voir le planning
    @merch = User.merch.find(params[:id])

    # Sessions planifiées du merch
    @sessions = @merch.work_sessions
                      .includes(:contract)
                      .order(:date, :start_time)
  end

  private

  def require_fve_or_admin!
    unless current_user&.fve? || current_user&.admin?
      redirect_to root_path, alert: 'Accès réservé aux forces de vente.'
    end
  end
end
