class ContractsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_contract, only: %i[show edit update destroy]

  def index
    @contracts = current_user.contracts.order(created_at: :desc)
  end

  def show
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
      :name, :agency, :contract_type,
      :night_rate, :km_rate, :km_limit, :km_unlimited,
      :ifm_rate, :cp_rate, :notes
    ).tap do |w|
      w[:ifm_rate]   = w[:ifm_rate].to_f   / 100 if w[:ifm_rate].present?
      w[:cp_rate]    = w[:cp_rate].to_f    / 100 if w[:cp_rate].present?
      w[:night_rate] = w[:night_rate].to_f / 100 if w[:night_rate].present?
    end
  end
end
