class ContractsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_contract, only: %i[show edit update destroy]

  def index
    @contracts = current_user.contracts.order(created_at: :desc)
  end

  def show
    # Déjà défini avec :set_contract
  end

  def new
    @contract = current_user.contracts.new
  end

  def create
    @contract = current_user.contracts.new(contract_params)

    if @contract.save
      redirect_to @contract, notice: 'Contrat créé avec succès.'
    else
      flash.now[:alert] = 'Erreur lors de la création du contrat.'
      render :new
    end
  end

  def edit
    # Déjà défini avec :set_contract
  end

  def update
    if @contract.update(contract_params)
      redirect_to @contract, notice: 'Contrat mis à jour.'
    else
      flash.now[:alert] = 'Erreur lors de la mise à jour.'
      render :edit
    end
  end

  def destroy
    @contract.destroy
    redirect_to contracts_path, notice: 'Contrat supprimé.'
  end

  private

  def set_contract
    @contract = current_user.contracts.find(params[:id])
  end

  def contract_params
    params.require(:contract).permit(
      :name, :agency, :contract_type, :start_date, :end_date,
      :hourly_rate, :night_rate, :km_rate, :km_limit, :km_unlimited,
      :ifm_rate, :cp_rate, :annex_minutes_per_hour, :annex_extra_minutes,
      :annex_threshold_hours, :notes
    )
  end
end
