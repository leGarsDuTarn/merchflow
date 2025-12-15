# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    if current_user.admin?
      redirect_to admin_dashboard_path and return
    elsif current_user.fve?
      redirect_to fve_dashboard_path and return
    end

    # ==========================================================
    # LOGIQUE DE DÉFAUT DU MOIS EN COURS (SI PAS DE PARAMÈTRE)
    # ==========================================================
    @year = (params[:year] || Date.current.year).to_i
    @month = (params[:month] || Date.current.month).to_i

    # Construction de la date cible pour les calculs (sécurisée)
    begin
      @target_date = Date.new(@year, @month, 1)
    rescue ArgumentError
      @target_date = Date.current.beginning_of_month
      @year = @target_date.year
      @month = @target_date.month
    end
    # Permet de cacher la notification si on regarde l'historique
    @is_current_month = (@target_date.beginning_of_month == Date.current.beginning_of_month)
    @user = current_user

    # --- Variables de navigation pour la vue ---
    @prev_month = (@target_date - 1.month).month
    @prev_year = (@target_date - 1.month).year
    @next_month = (@target_date + 1.month).month
    @next_year = (@target_date + 1.month).year

    # --- Données du mois sélectionné (doivent utiliser @target_date) ---
    @total_hours_month      = @user.total_hours_for_month(@target_date)
    @total_brut_month       = @user.total_brut_for_month(@target_date)
    @net_estimated_month    = @user.net_estimated_for_month(@target_date)
    @net_total_estimated_month = @user.net_total_estimated_for_month(@target_date)
    @km_month               = @user.total_km_for_month(@target_date)
    @km_payment_month       = @user.total_km_payment_for_month(@target_date)

    # Calculer le compte pour la carte de notification
    @pending_proposals_count = @user.received_mission_proposals
                                    .where(status: :pending)
                                    .count

    # L'ancienne variable @pending_proposals n'est plus nécessaire ici.

    @by_agency = @user.total_by_agency_for_month(@target_date) || []

    # ==========================================================
    # LOGIQUE D'ALERTE VISIBILITÉ (POUR MERCH)
    # ==========================================================
    @show_visibility_alert = false

    if @user.merch?
      # Récupération des settings ou réation d'un vide en mémoire pour éviter le crash nil
      settings = @user.merch_setting || @user.build_merch_setting

      # L'alerte s'affiche SI : le planning n'est pas partagé OU l'identité est masquée
      if !settings.share_planning || !settings.allow_identity
        @show_visibility_alert = true
      end
    end
  end
end
