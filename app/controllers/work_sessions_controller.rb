class WorkSessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_contract, only: %i[index new create]
  before_action :set_work_session, only: %i[show edit update destroy]

  # ============================================================
  # INDEX
  # ============================================================
  def index
    # Récupérer la query pour la repasser à la vue
    @query = params[:query]

    # 1. Définition du scope de base
    if @contract
      scope = @contract.work_sessions.order(date: :desc)
    else
      scope = WorkSession.joins(:contract)
                       .where(contracts: { user_id: current_user.id })
                       .order(date: :desc)
    end

    # 2. Application de la recherche (si présente)
    if @query.present?
      q = "%#{@query}%"
      scope = scope.where("
        work_sessions.company ILIKE :q
        OR work_sessions.store ILIKE :q
        OR TO_CHAR(work_sessions.date, 'YYYY-MM-DD') ILIKE :q
        ", q: q)
    end

    # 3. Pagination Pagy
    @pagy, @work_sessions = pagy(scope, items: 6)
  end

  # ============================================================
  # SHOW
  # ============================================================
  def show
    # Déjà définie par :set_work_session
  end

  # ============================================================
  # NEW
  # ============================================================
  def new
    if @contract
      # Cas 1 : Route imbriquée, contrat fixé par l'URL
      @work_session = @contract.work_sessions.new
    else
      # Cas 2 : Dashboard, pas de contrat fixé
      @work_session = WorkSession.new
    end

    # Si on vient du calendrier (paramètre ?date=2023-11-26)
    # On pré-remplit le champ date
    if params[:date].present?
      @work_session.date = params[:date]
    end
  end

  # ============================================================
  # CREATE
  # ============================================================
  def create
    if @contract
      # Cas 1 : Imbriqué
      @work_session = @contract.work_sessions.new(work_session_params)
    else
      # Cas 2 : Dashboard
      @work_session = WorkSession.new(work_session_params)

      # Sécurité : on vérifie que le contrat appartient au user
      submitted_contract_id = work_session_params[:contract_id]
      unless current_user.contracts.exists?(id: submitted_contract_id)
        flash.now[:alert] = "Contrat invalide."
        render :new, status: :unprocessable_entity and return
      end
    end

    if @work_session.save
      redirect_to @work_session, notice: "Mission enregistrée."
    else
      flash.now[:alert] = "Erreur lors de l’enregistrement."
      # @contract reste nil ici dans le Cas 2, donc le select s'affichera
      render :new, status: :unprocessable_entity
    end
  end

  # ============================================================
  # EDIT
  # ============================================================
  def edit
    # Déjà définie par :set_work_session
  end

  # ============================================================
  # UPDATE (C'était cette méthode qui manquait !)
  # ============================================================
  def update
    if @work_session.update(work_session_params)
      redirect_to @work_session, notice: "Mise à jour faite."
    else
      flash.now[:alert] = "Erreur lors de la mise à jour."
      render :edit, status: :unprocessable_entity
    end
  end

  # ============================================================
  # DESTROY
  # ============================================================
  def destroy
    contract = @work_session.contract
    @work_session.destroy
    redirect_to contract_path(contract), notice: "Mission supprimée."
  end

  # ============================================================
  # PRIVATE
  # ============================================================
  private

  def set_contract
    return unless params[:contract_id]
    @contract = current_user.contracts.find(params[:contract_id])
  end

  def set_work_session
    @work_session = WorkSession.joins(:contract)
                               .where(contracts: { user_id: current_user.id })
                               .find(params[:id])
  end

  def work_session_params
    params.require(:work_session).permit(
      :contract_id, :company,
      :date, :start_time, :end_time, :shift, :store,
      :store_full_address, :notes,
      :recommended, :km_custom, :hourly_rate
    )
  end
end
