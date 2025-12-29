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

    # Inscrits ce MOIS-CI (depuis le 1er du mois)
    @new_users_month = User.where(role: [:merch, :fve])
                           .where('created_at >= ?', @start_of_month)
                           .count

    # Inscrits cette SEMAINE (7 jours glissants)
    @new_users_week = User.where(role: [:merch, :fve])
                          .where('created_at >= ?', 7.days.ago)
                          .count

    # Graphique Inscriptions (7 derniers jours)
    last_7_days = (6.days.ago.to_date..Date.current)
    registrations = User.where(role: [:merch, :fve])
                        .where('created_at >= ?', 7.days.ago)
                        .group("DATE(created_at)")
                        .count

    @registrations_by_day = last_7_days.each_with_object({}) do |date, hash|
      hash[date] = registrations[date] || 0
    end

    # ==========================================================
    # 2. ENGAGEMENT (Utilisateurs actifs sur 7 jours)
    # ==========================================================
    active_7d_ids = WorkSession.where(created_at: 7.days.ago..Time.current)
                               .pluck(:contract_id)
                               .then { |ids| Contract.where(id: ids).pluck(:user_id).uniq }

    active_count_7d = User.where(id: active_7d_ids).where.not(role: :admin).count
    @engagement_rate = @total_users > 0 ? ((active_count_7d.to_f / @total_users) * 100).round(1) : 0.0

    # ==========================================================
    # 3. COMPTES DORMANTS (Correction "Lancement")
    # ==========================================================
    # On ne considère "Dormant" que si l'utilisateur est inscrit depuis + de 7 jours
    # et n'a rien fait depuis 30 jours.

    # A. Le Pool : Combien d'utilisateurs ont + de 7 jours d'ancienneté ?
    users_older_than_7d_count = User.where(role: [:merch, :fve])
                                    .where('created_at < ?', 7.days.ago)
                                    .count

    # B. Les Actifs parmi eux : Qui a bossé dans les 30 derniers jours ?
    active_30d_ids = WorkSession.where('created_at >= ?', 30.days.ago).pluck(:contract_id)
                                .then { |ids| Contract.where(id: ids).pluck(:user_id).uniq }

    active_older_users_count = User.where(id: active_30d_ids)
                                   .where('created_at < ?', 7.days.ago)
                                   .where.not(role: :admin)
                                   .count

    # C. Calcul : Fantômes = (Vieux utilisateurs) - (Ceux qui sont actifs)
    @ghost_users_count = users_older_than_7d_count - active_older_users_count

    # D. Taux calculé uniquement sur les utilisateurs éligibles
    @churn_rate = users_older_than_7d_count > 0 ? ((@ghost_users_count.to_f / users_older_than_7d_count) * 100).round(1) : 0.0


    # ==========================================================
    # 4. VOLUME & MONÉTISATION
    # ==========================================================
    @total_volume_month = WorkSession.where(date: @start_of_month..Time.current).sum do |ws|
      ((ws.duration_minutes / 60.0) * (ws.hourly_rate || 11.88)) + ws.fee_meal.to_f + ws.fee_parking.to_f + ws.fee_toll.to_f
    end

    @total_premium_fve = User.fve.where(premium: true).count
    @premium_conversion_rate = @total_fve > 0 ? ((@total_premium_fve.to_f / @total_fve) * 100).round(1) : 0.0

    # ==========================================================
    # 5. ACTIVITÉ & MISSIONS
    # ==========================================================

    # Missions du mois en cours
    work_sessions_this_month_records = WorkSession.where(date: @start_of_month..Time.current)
    @work_sessions_month = work_sessions_this_month_records.count

    # --- NOUVEAU : TOTAL ABSOLU (ALL TIME) ---
    @total_work_sessions_all_time = WorkSession.count

    # Temps moyen (basé sur le mois pour la pertinence)
    total_duration = work_sessions_this_month_records.sum(:duration_minutes)
    if @work_sessions_month > 0
      avg = (total_duration.to_f / @work_sessions_month).round(0)
      @avg_mission_time_formatted = "#{avg / 60}h #{avg % 60}min"
    else
      @avg_mission_time_formatted = "0h 0min"
    end

    # ==========================================================
    # 6. INVITATIONS
    # ==========================================================
    @invitations_total  = FveInvitation.count
    @invitations_unused = FveInvitation.where(used: false).where('expires_at > ?', Time.current).count
  end
end
