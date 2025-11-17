class KilometerLogsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_work_session

  def create
    @log = @work_session.kilometer_logs.new(km_params)

    if @log.save
      redirect_to @work_session, notice: 'Kilométrage ajouté.'
    else
      redirect_to @work_session, alert: "Erreur lors de l'ajout."
    end
  end

  def destroy
    log = @work_session.kilometer_logs.find(params[:id])
    log.destroy
    redirect_to @work_session, notice: 'Ligne supprimée.'
  end

  private

  def set_work_session
    @work_session = WorkSession
                    .joins(:contract)
                    .where(contracts: { user_id: current_user.id })
                    .find(params[:work_session_id])
  end

  def km_params
    params.require(:kilometer_log).permit(:distance, :description, :km_rate)
  end
end
