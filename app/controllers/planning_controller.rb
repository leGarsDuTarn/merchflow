class PlanningController < ApplicationController
  before_action :authenticate_user!

  def index
    # Permet des récupérer mois et année actuels
    @year  = (params[:year]  || Date.today.year).to_i
    @month = (params[:month] || Date.today.month).to_i

    # Sessions filtrées
    @sessions = current_user.work_sessions.for_month(@year, @month)
    @sessions_by_date = @sessions.group_by(&:date)

    # Indisponibilités du mois
    @unavailabilities = current_user.unavailabilities.where(date: Date.new(@year, @month).all_month)
    @unavailable_dates = @unavailabilities.pluck(:date)

    # Pour naviguer dans les mois
    date = Date.new(@year, @month)
    prev = date.prev_month
    nxt  = date.next_month

    @prev_year  = prev.year
    @prev_month = prev.month
    @next_year  = nxt.year
    @next_month = nxt.month

    # Génération des semaines du mois
    @weeks = generate_calendar(date)
  end

  private

  # Retourne un tableau d'arrays représentant les semaines du mois
  def generate_calendar(date)
    first_day = date.beginning_of_month.beginning_of_week(:monday)
    last_day  = date.end_of_month.end_of_week(:monday)

    (first_day..last_day).to_a.in_groups_of(7)
  end
end
