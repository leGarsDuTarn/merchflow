class Fve::MerchController < ApplicationController
  before_action :authenticate_user!
  before_action :require_fve!

  def index
    authorize %i[fve merch]
    # Tous les merch (role = 0)
    @merch = User.merch.order(:firstname, :lastname)
  end

  def show
    @merch_user = User.merch.find(params[:id])
    authorize [:fve, @merch_user]

    # ========== CONFIDENTIALITÉ : DONNÉES AFFICHABLES ==========
    @name  = @merch_user.displayable_name(current_user)
    @email = @merch_user.displayable_email(current_user)
    @phone = @merch_user.displayable_phone(current_user)
  end

  private

  def require_fve!
    unless current_user&.fve?
      redirect_to root_path, alert: 'Accès réservé aux forces de vente.'
    end
  end
end
