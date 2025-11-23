class DeclarationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_contract, only: %i[index create]  # <-- gardé pour ton système actuel

  # ============================================
  # FRANCE TRAVAIL (global, tous employeurs)
  # ============================================
  def france_travail
    # Si une date YYYY-MM a été envoyée par la barre de recherche
    if params[:date].present?
      parsed = Date.parse("#{params[:date]}-01")
      @year  = parsed.year
      @month = parsed.month
    else
      @year  = (params[:year]  || Date.today.year).to_i
      @month = (params[:month] || Date.today.month).to_i
    end

    # NORMALISATION mois <1 ou >12
    if @month < 1
      @month = 12
      @year -= 1
    end

    if @month > 12
      @month = 1
      @year += 1
    end

    # WORK SESSIONS pour le mois demandé
    @sessions = current_user.work_sessions.for_month(@year, @month)
    @grouped  = @sessions.group_by { |ws| ws.contract.agency }
  end

  # ============================================
  # DÉCLARATIONS PAR CONTRAT (ton système actuel)
  # ============================================
  def index
    @declarations = @contract.declarations.order(year: :desc, month: :desc)
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
