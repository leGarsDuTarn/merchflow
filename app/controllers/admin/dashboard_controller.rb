class Admin::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  def index
    authorize %i[admin dashboard]

    @start_of_month = Time.current.beginning_of_month

    # ==========================================================
    # 1. BASE UTILISATEUR
    # ==========================================================
    @total_merch = User.merch.count
    @total_fve   = User.fve.count
    @total_users = @total_merch + @total_fve

    @new_users_month = User.where(role: [:merch, :fve]).where('created_at >= ?', @start_of_month).count
    @new_users_week  = User.where(role: [:merch, :fve]).where('created_at >= ?', 7.days.ago).count

    # Graphique Inscriptions (On garde 7j pour le graph, c'est bien pour voir la tendance immédiate)
    last_7_days = (6.days.ago.to_date..Date.current)
    registrations = User.where(role: [:merch, :fve]).where('created_at >= ?', 7.days.ago).group("DATE(created_at)").count
    @registrations_by_day = last_7_days.each_with_object({}) { |date, hash| hash[date] = registrations[date] || 0 }

    # permet d'afficher les 3 derniers inscrit sur la plateforme
    @last_registrations = User.where(role: [:merch, :fve])
                              .order(created_at: :desc)
                              .limit(3)
    # ==========================================================
    # 2. ENGAGEMENT (MODIFIÉ : 30 JOURS)
    # ==========================================================
    # On regarde les actifs sur 30 jours au lieu de 7
    active_30d_ids = WorkSession.where(created_at: 30.days.ago..Time.current)
                                .pluck(:contract_id)
                                .then { |ids| Contract.where(id: ids).pluck(:user_id).uniq }

    active_count_30d = User.where(id: active_30d_ids).where.not(role: :admin).count
    @engagement_rate = @total_users > 0 ? ((active_count_30d.to_f / @total_users) * 100).round(1) : 0.0

    # ==========================================================
    # 3. TAUX DE CHURN (MODIFIÉ : 30 JOURS)
    # ==========================================================
    # Définition adaptée au cycle mensuel :
    # "Dormant" = Inscrit depuis + de 30 jours ET inactif depuis 30 jours.

    # A. Le Pool : Utilisateurs inscrits depuis au moins 30 jours (avant on ignorait les trop récents)
    users_older_than_30d_count = User.where(role: [:merch, :fve])
                                     .where('created_at < ?', 30.days.ago)
                                     .count

    # B. Les Actifs parmi les anciens (ceux qui ont bossé dans les 30 derniers jours)
    # Note : active_30d_ids est déjà calculé au dessus, on filtre juste sur l'ancienneté
    active_older_users_count = User.where(id: active_30d_ids)
                                   .where('created_at < ?', 30.days.ago)
                                   .where.not(role: :admin)
                                   .count

    # C. Calcul
    @ghost_users_count = users_older_than_30d_count - active_older_users_count
    @churn_rate = users_older_than_30d_count > 0 ? ((@ghost_users_count.to_f / users_older_than_30d_count) * 100).round(1) : 0.0


    # ==========================================================
    # 4. VOLUME & MONÉTISATION (MODIFIÉ : TOTAL + MOIS)
    # ==========================================================

    # Volume du MOIS
    @total_volume_month = calculate_volume(WorkSession.where(date: @start_of_month..Time.current))

    # Volume TOTAL (Depuis le début)
    @total_volume_all_time = calculate_volume(WorkSession.all)

    @total_premium_fve = User.fve.where(premium: true).count
    @premium_conversion_rate = @total_fve > 0 ? ((@total_premium_fve.to_f / @total_fve) * 100).round(1) : 0.0

    # ==========================================================
    # 5. ACTIVITÉ & MISSIONS
    # ==========================================================
    work_sessions_this_month_records = WorkSession.where(date: @start_of_month..Time.current)
    @work_sessions_month = work_sessions_this_month_records.count
    @total_work_sessions_all_time = WorkSession.count

    total_duration = work_sessions_this_month_records.sum(:duration_minutes)
    if @work_sessions_month > 0
      avg = (total_duration.to_f / @work_sessions_month).round(0)
      @avg_mission_time_formatted = "#{avg / 60}h #{avg % 60}min"
    else
      @avg_mission_time_formatted = "0h 0min"
    end

    # 6. INVITATIONS
    @invitations_total  = FveInvitation.count
    @invitations_unused = FveInvitation.where(used: false).where('expires_at > ?', Time.current).count
  end

  private

  # Petite méthode privée pour éviter de dupliquer la logique de calcul
  def calculate_volume(scope)
    scope.sum do |ws|
      ((ws.duration_minutes / 60.0) * (ws.hourly_rate || 11.88)) + ws.fee_meal.to_f + ws.fee_parking.to_f + ws.fee_toll.to_f
    end
  end
end
