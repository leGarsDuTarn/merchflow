class Fve::PlanningsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_fve!

  def show
    @merch = User.merch.find(params[:id])

    # Chargement des missions visibles
    @work_sessions = @merch.work_sessions.order(date: :asc)
  end

  private

  def require_fve!
    unless current_user&.fve?
      redirect_to root_path, alert: 'Accès réservé aux forces de vente.'
    end
  end
end
