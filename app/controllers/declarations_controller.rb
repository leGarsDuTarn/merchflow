class DeclarationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_contract, only: %i[index create]

  def index
    @declarations = @contract.declarations.order(year: :desc, month: :desc)
  end

  def france_travail
    @user = current_user
    @contracts = current_user.contracts.includes(:work_sessions)
  end

  def create
    month = params[:month].to_i
    year  = params[:year].to_i

    declaration = Declarations::Generator.new(@contract, month, year).call

    if declaration.save
      redirect_to contract_declarations_path(@contract), notice: 'Déclaration générée.'
    else
      redirect_to contract_declarations_path(@contract), alert: declaration.errors.full_messages.to_sentence
    end
  end

  private

  def set_contract
    @contract = current_user.contracts.find(params[:contract_id])
  end
end
