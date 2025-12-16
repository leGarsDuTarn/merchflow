# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    # Redirection selon le rôle
    if current_user.admin?
      redirect_to admin_dashboard_path and return
    elsif current_user.fve?
      redirect_to fve_dashboard_path and return
    end

    # ==========================================================
    # 1. GESTION DE LA DATE (Mois en cours ou navigation)
    # ==========================================================
    @year = (params[:year] || Date.current.year).to_i
    @month = (params[:month] || Date.current.month).to_i

    begin
      @target_date = Date.new(@year, @month, 1)
    rescue ArgumentError
      @target_date = Date.current.beginning_of_month
      @year = @target_date.year
      @month = @target_date.month
    end

    @is_current_month = (@target_date.beginning_of_month == Date.current.beginning_of_month)
    @user = current_user

    # Variables de navigation (Mois précédent / suivant)
    @prev_month = (@target_date - 1.month).month
    @prev_year  = (@target_date - 1.month).year
    @next_month = (@target_date + 1.month).month
    @next_year  = (@target_date + 1.month).year

    # ==========================================================
    # 2. CALCULS FINANCIERS (PRÉCIS)
    # ==========================================================

    # HEURES : On récupère le décimal exact (ex: 7.75)
    @total_hours_month = @user.total_hours_for_month(@target_date)

    # BRUT : On appelle la méthode qui inclut (Salaire + IFM + CP)
    # C'est ce qui permet d'avoir le vrai montant brut dans le badge
    @total_brut_month = @user.total_complete_brut_for_month(@target_date)

    # NET TOTAL : La somme exacte des virements estimés de chaque mission
    # (Inclut Salaire Net + IFM Net + CP Net + Frais KM)
    @net_total_estimated_month = @user.net_total_estimated_for_month(@target_date)

    # KM & FRAIS KM
    @km_month         = @user.total_km_for_month(@target_date)
    @km_payment_month = @user.total_km_payment_for_month(@target_date)

    # NET HORS KM (Pour information uniquement)
    # Calcul : Net Total - Frais KM
    @net_estimated_month = (@net_total_estimated_month - @km_payment_month).round(2)

    # ==========================================================
    # 3. DONNÉES ANNEXES (Agence, Notifications)
    # ==========================================================

    # Propositions en attente pour le compteur
    @pending_proposals_count = @user.received_mission_proposals
                                    .where(status: :pending)
                                    .count

    # Tableau détaillé par agence
    @by_agency = @user.total_by_agency_for_month(@target_date) || []

    # ==========================================================
    # 4. ALERTE VISIBILITÉ (Pour Merch)
    # ==========================================================
    @show_visibility_alert = false

    if @user.merch?
      settings = @user.merch_setting || @user.build_merch_setting
      if !settings.share_planning || !settings.allow_identity
        @show_visibility_alert = true
      end
    end
  end
end
