# app/controllers/fve/plannings_controller.rb
module Fve
  class PlanningsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_fve!

    def show
      authorize %i[fve plannings]

      @merch_user = User.merch.find(params[:id])

      # 🚨 VÉRIFICATION DE SÉCURITÉ CRITIQUE : Droit de voir le planning
      # On vérifie si l'utilisateur Merch a autorisé le partage du planning.
      # On s'assure d'abord que le merch_setting existe pour éviter un crash.
      unless @merch_user.merch_setting&.share_planning?
        redirect_to fve_merch_path(@merch_user),
                    alert: "Accès refusé : Le prestataire n'a pas autorisé le partage de son planning."
        return
      end

      @year  = (params[:year]  || Date.today.year).to_i
      @month = (params[:month] || Date.today.month).to_i

      date = Date.new(@year, @month)

      # NOTE: Si for_month est défini dans WorkSession, on peut l'utiliser directement.
      # Sinon, utilisez le scope :for_month que vous avez fourni.
      @sessions = @merch_user.work_sessions.for_month(@year, @month)
      @sessions_by_date = @sessions.group_by(&:date)

      @unavailabilities = @merch_user.unavailabilities.where(date: date.all_month)
      @unavailable_dates = @unavailabilities.pluck(:date)


      # Navigation mois
      prev = date.prev_month
      nxt  = date.next_month
      @prev_year  = prev.year
      @prev_month = prev.month
      @next_year  = nxt.year
      @next_month = nxt.month

      # Génération calendrier
      @weeks = generate_calendar(date)
    end

    private

    def require_fve!
      redirect_to root_path, alert: 'Accès réservé aux forces de vente.' unless current_user&.fve?
    end

    def generate_calendar(date)
      # Calcule le premier et dernier jour à afficher
      first_day = date.beginning_of_month.beginning_of_week(:monday)
      last_day  = date.end_of_month.end_of_week(:monday)

      # Crée un tableau de jours groupés par semaine de 7 jours
      (first_day..last_day).to_a.in_groups_of(7)
    end
  end
end
