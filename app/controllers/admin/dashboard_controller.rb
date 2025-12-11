class Admin::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  def index
    authorize %i[admin dashboard]

    # --- Périodes de référence ---
    start_of_month = Time.current.beginning_of_month
    start_of_week  = 7.days.ago

    # ==========================================================
    # 1. STATISTIQUES GLOBALES & BASE UTILISATEUR
    # ==========================================================
    @total_users        = User.count
    @total_merch        = User.merch.count
    @total_fve          = User.fve.count
    @total_premium_fve  = User.fve.where(premium: true).count
    @new_users_month    = User.where('created_at >= ?', start_of_month).count

    # ==========================================================
    # 2. SANTÉ GLOBALE ET CROISSANCE (KPIs)
    # ==========================================================

    # KPI 1: Taux d'Engagement (Utilisateurs actifs via WorkSession la semaine dernière)
    active_users_last_week_count = User.joins(contracts: :work_sessions)
                                     .where(work_sessions: { created_at: start_of_week..Time.current })
                                     .distinct
                                     .count

    @engagement_rate = if @total_users > 0
                         ((active_users_last_week_count.to_f / @total_users) * 100).round(1)
                       else
                         0.0
                       end

    # ==========================================================
    # 3. MONÉTISATION ET CONVERSION
    # ==========================================================

    # KPI 3: Taux de Conversion Premium (basé sur les FVE)
    @premium_conversion_rate = if @total_fve > 0
                                 ((@total_premium_fve.to_f / @total_fve) * 100).round(1)
                               else
                                 0.0
                               end

    # ==========================================================
    # 4. FLUX DE TRAVAIL ET EFFICACITÉ
    # ==========================================================

    # Activité des merch (déjà présent)
    @work_sessions_month = WorkSession.where('date >= ?', Date.current.beginning_of_month).count

    # Temps Moyen par Mission (Utilisation de duration_minutes)
    total_duration_minutes = WorkSession.where('created_at >= ?', start_of_month).sum(:duration_minutes)

    work_sessions_this_month = WorkSession.where('created_at >= ?', start_of_month).count

    if work_sessions_this_month > 0
      # 1. Calculer la moyenne en minutes
      avg_minutes = (total_duration_minutes.to_f / work_sessions_this_month).round(0)

      # 2. Convertir en Hh MMmin
      hours = avg_minutes / 60
      minutes = avg_minutes % 60

      # Stockage du format lisible pour la vue
      @avg_mission_time_formatted = "#{hours}h #{minutes}min"
    else
      @avg_mission_time_formatted = "0h 0min"
    end


    # ==========================================================
    # 5. GESTION DES INVITATIONS
    # ==========================================================

    @invitations_total      = FveInvitation.count
    @invitations_used       = FveInvitation.where(used: true).count

    @invitations_expired    = FveInvitation.where('expires_at < ?', Time.current).where(used: false).count

    @invitations_unused = @invitations_total - @invitations_used - @invitations_expired

    @unused_invitations_ratio = if @invitations_total > 0
                                  ((@invitations_unused.to_f / @invitations_total) * 100).round(1)
                                else
                                  0.0
                                end
  end
end
