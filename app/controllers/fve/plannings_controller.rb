class Fve::PlanningsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_fve!

  def show
    authorize %i[fve plannings]

    @merch_user = User.merch.find(params[:id])

    @year  = (params[:year]  || Date.today.year).to_i
    @month = (params[:month] || Date.today.month).to_i

    date = Date.new(@year, @month)

    @sessions = @merch_user.work_sessions.for_month(@year, @month)
    @sessions_by_date = @sessions.group_by(&:date)


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
    first_day = date.beginning_of_month.beginning_of_week(:monday)
    last_day  = date.end_of_month.end_of_week(:monday)
    (first_day..last_day).to_a.in_groups_of(7)
  end
end
