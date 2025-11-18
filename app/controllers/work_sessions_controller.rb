class WorkSessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_contract, only: %i[index new create]
  before_action :set_work_session, only: %i[show edit update destroy]

  def index
    @work_sessions = @contract.work_sessions.order(date: :desc)
  end

  def show
    # Déjà défini par :set_work_session
  end

  def new
    @work_session = @contract.work_sessions.new
  end

  def create
    @work_session = @contract.work_sessions.new(work_session_params)

    if @work_session.save
      redirect_to @work_session, notice: "Mission enregistrée."
    else
      flash.now[:alert] = "Erreur lors de l’enregistrement."
      render :new
    end
  end

  def edit
    # Déjà défini par :set_work_session
  end

  def update
    if @work_session.update(work_session_params)
      redirect_to @work_session, notice: "Mise à jour faite."
    else
      flash.now[:alert] = "Erreur lors de la mise à jour."
      render :edit
    end
  end

  def destroy
    contract = @work_session.contract
    @work_session.destroy
    redirect_to contract_path(contract), notice: "Mission supprimée."
  end

  private

  # Ici set_contract est nécessaire car pour créer une WorkSession,
  # ont doit savoir à quel contrat elle appartient
  def set_contract
    @contract = current_user.contracts.find(params[:contract_id])
  end

  def set_work_session
    @work_session = WorkSession.joins(:contract)
                               .where(contracts: { user_id: current_user.id })
                               .find(params[:id])
  end

  def work_session_params
    params.require(:work_session).permit(
      :date, :start_time, :end_time, :break_minutes, :shift, :store,
      :store_full_address, :notes, :meal_allowance, :meal_hours_required,
      :recommended, :km_custom, :hourly_rate
    )
  end
end
