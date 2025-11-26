class Fve::MerchController < ApplicationController
  before_action :authenticate_user!
  before_action :require_fve!

  def index
    # Tous les merch (role=0)
    @merch = User.merch.order(:firstname)
  end

  def show
    @merch = User.merch.find(params[:id])
  end

  private

  def require_fve!
    unless current_user&.fve?

      redirect_to root_path, alert: 'Accès réservé aux forces de vente.'
    end
  end
end
