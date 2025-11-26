class Fve::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :verify_fve

  def index
    authorize %i[fve dashboard]

    @total_merch = User.merch.count
    @premium = current_user.premium?
    # Tous les merch (uniquement role merch)
    @merch_users = User.merch.order(:firstname)
  end

  private

  def verify_fve
    unless current_user&.fve?
      redirect_to root_path, alert: 'Accès réservé aux forces de vente.'
    end
  end
end
