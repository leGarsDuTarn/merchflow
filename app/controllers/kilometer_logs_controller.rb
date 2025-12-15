class KilometerLogsController < ApplicationController
  before_action :authenticate_user!

  def index
    # 1. Gestion de l'année (Par défaut l'année courante, ou celle demandée)
    @year = params[:year].presence&.to_i || Date.current.year
    @selected_month = params[:month].presence&.to_i

    # 2. Scope de base : On cherche les WORK SESSIONS (Missions)
    # On filtre :
    # - Celles de l'utilisateur courant (via Contract)
    # - Celles de l'année choisie
    # - Celles qui ont des km (soit custom, soit effectif)
    base_scope = WorkSession.joins(:contract)
                            .where(contracts: { user_id: current_user.id })
                            .where("EXTRACT(YEAR FROM work_sessions.date) = ?", @year)
                            .where("COALESCE(work_sessions.km_custom, work_sessions.effective_km) > 0")

    # 3. Calculs des KPIs globaux pour l'année
    # On additionne km_custom s'il existe, sinon effective_km
    @total_distance = base_scope.sum("COALESCE(work_sessions.km_custom, work_sessions.effective_km)")

    # Montant déductible : (Distance * Taux du contrat)
    # Note : On utilise le taux actuel du contrat associé à la mission
    @total_deductible = base_scope.sum("COALESCE(work_sessions.km_custom, work_sessions.effective_km) * COALESCE(contracts.km_rate, 0)")

    # 4. Groupement par mois pour le tableau récapitulatif
    @monthly_data = base_scope.group("EXTRACT(MONTH FROM work_sessions.date)")
                              .select("EXTRACT(MONTH FROM work_sessions.date) as month,
                                       SUM(COALESCE(work_sessions.km_custom, work_sessions.effective_km)) as total_km,
                                       SUM(COALESCE(work_sessions.km_custom, work_sessions.effective_km) * COALESCE(contracts.km_rate, 0)) as total_amount")
                              .order("month ASC")

    # 5. Récupération de la liste détaillée des missions
    @logs = base_scope.includes(:contract).order(date: :desc)

    # Filtre optionnel si on clique sur un mois précis
    if @selected_month
      @logs = @logs.where("EXTRACT(MONTH FROM work_sessions.date) = ?", @selected_month)
    end
  end
end
