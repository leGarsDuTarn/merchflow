class Admin::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  def index
    authorize %i[admin dashboard]

    @start_of_month = Time.current.beginning_of_month

    # ==========================================================
    # 1. BASE UTILISATEUR (SANS ADMIN)
    # ==========================================================
    @total_merch = User.merch.count
    @total_fve   = User.fve.count
    @total_users = @total_merch + @total_fve

    # --- NOUVEAU : Calcul Semaine vs Mois ---

    # Inscrits ce MOIS-CI (depuis le 1er du mois)
    @new_users_month = User.where(role: [:merch, :fve])
                           .where('created_at >= ?', @start_of_month)
                           .count

    # Inscrits cette SEMAINE (7 jours glissants)
    @new_users_week = User.where(role: [:merch, :fve])
                          .where('created_at >= ?', 7.days.ago)
                          .count

    # Inscriptions graphiques (7 derniers jours)
    last_7_days = (6.days.ago.to_date..Date.current)
    registrations = User.where(role: [:merch, :fve])
                        .where('created_at >= ?', 7.days.ago)
                        .group("DATE(created_at)")
                        .count

    @registrations_by_day = last_7_days.each_with_object({}) do |date, hash|
      hash[date] = registrations[date] || 0
    end

    # ... (Le reste du contrôleur reste inchangé pour l'engagement, volume, etc.) ...
    # Je te remets la suite juste pour que le code ne plante pas si tu copies-colles tout

    # ENGAGEMENT
    active_7d_ids = WorkSession.where(created_at: 7.days.ago..Time.current).pluck(:contract_id)
                               .then { |ids| Contract.where(id: ids).pluck(:user_id).uniq }
    active_count_7d = User.where(id: active_7d_ids).where.not(role: :admin).count
    @engagement_rate = @total_users > 0 ? ((active_count_7d.to_f / @total_users) * 100).round(1) : 0.0

    # CHURN
    active_30d_ids = WorkSession.where('created_at >= ?', 30.days.ago).pluck(:contract_id)
                                .then { |ids| Contract.where(id: ids).pluck(:user_id).uniq }
    active_users_count = User.where(id: active_30d_ids).where.not(role: :admin).count
    @ghost_users_count = @total_users - active_users_count
    @churn_rate = @total_users > 0 ? ((@ghost_users_count.to_f / @total_users) * 100).round(1) : 0.0

    # VOLUME
    @total_volume_month = WorkSession.where(date: @start_of_month..Time.current).sum do |ws|
      ((ws.duration_minutes / 60.0) * (ws.hourly_rate || 11.88)) + ws.fee_meal.to_f + ws.fee_parking.to_f + ws.fee_toll.to_f
    end

    # PREMIUM
    @total_premium_fve = User.fve.where(premium: true).count
    @premium_conversion_rate = @total_fve > 0 ? ((@total_premium_fve.to_f / @total_fve) * 100).round(1) : 0.0

    # ACTIVITÉ
    work_sessions_this_month_records = WorkSession.where(date: @start_of_month..Time.current)
    @work_sessions_month = work_sessions_this_month_records.count
    total_duration = work_sessions_this_month_records.sum(:duration_minutes)
    @avg_mission_time_formatted = @work_sessions_month > 0 ? "#{total_duration / 60 / 60}h #{(total_duration / 60) % 60}min" : "0h 0min"

    # INVITATIONS
    @invitations_total  = FveInvitation.count
    @invitations_unused = FveInvitation.where(used: false).where('expires_at > ?', Time.current).count
  end
end
