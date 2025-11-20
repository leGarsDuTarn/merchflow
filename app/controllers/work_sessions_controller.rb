class WorkSessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_contract, only: %i[index new create]
  before_action :set_work_session, only: %i[show edit update destroy]

  # ============================================================
  # INDEX
  # ============================================================
  def index
    @work_sessions = @contract.work_sessions.order(date: :desc)
  end

  # ============================================================
  # SHOW
  # ============================================================
  def show
    # Déjà définie par :set_work_session
  end

  # ============================================================
  # NEW (Simplifié pour se baser sur set_contract)
  # ============================================================
  def new
    # CHANGE : set_contract gère déjà si params[:contract_id] est présent et définit @contract.
    # On se base sur cette variable.
    if @contract # Cas 1 : on passe par un contrat → /contracts/:id/work_sessions/new
      @work_session = @contract.work_sessions.new
    else # Cas 2 : on passe par le dashboard → /work_sessions/new
      @work_session = WorkSession.new
      # @contract est déjà nil grâce à set_contract
    end
  end

  # ============================================================
  # CREATE
  # ============================================================
  def create
    # Cas 1 : on vient d’un contrat (le contract_id est dans le formulaire,
    # même si l'URL était imbriquée, la logique de new l'aurait défini)
    if params[:work_session][:contract_id].present?
      @contract = current_user.contracts.find(params[:work_session][:contract_id])
      @work_session = @contract.work_sessions.new(work_session_params)

    # Cas 2 : création depuis dashboard (sélection contrat dans form)
    else
      @work_session = WorkSession.new(work_session_params)

      # SÉCURITÉ : l'utilisateur ne peut créer une mission que dans SES contrats
      unless current_user.contracts.exists?(@work_session.contract_id)
        # CHANGE : Assurer que @contract est nil en cas d'erreur de sécurité
        @contract = nil
        flash.now[:alert] = "Contrat invalide."
        return render :new
      end
    end

    if @work_session.save
      redirect_to @work_session, notice: "Mission enregistrée."
    else
      # CHANGE : Si l'enregistrement échoue, nous devons garantir que @contract est nil
      # uniquement si nous sommes dans le Cas 2 pour que le champ de sélection s'affiche.
      # Si params[:work_session][:contract_id].blank? est vrai (Cas 2), on force @contract = nil.
      if params[:work_session][:contract_id].blank?
         @contract = nil
      end

      flash.now[:alert] = "Erreur lors de l’enregistrement."
      render :new
    end
  end

  # ============================================================
  # EDIT & UPDATE
  # ============================================================
  def edit
    # Déjà définie par :set_work_session
  end

  def update
    if @work_session.update(work_session_params)
      redirect_to @work_session, notice: "Mise à jour faite."
    else
      flash.now[:alert] = "Erreur lors de la mise à jour."
      render :edit
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

  # Pour les routes imbriquées /contracts/:id/work_sessions
  def set_contract
    # Aucune modification ici. Définit @contract seulement si params[:contract_id] est dans l'URL.
    @contract = current_user.contracts.find(params[:contract_id]) if params[:contract_id]
  end

  # WorkSession accessible uniquement si elle appartient à un contrat du user
  def set_work_session
    @work_session = WorkSession.joins(:contract)
                               .where(contracts: { user_id: current_user.id })
                               .find(params[:id])
  end

  def work_session_params
    params.require(:work_session).permit(
      :contract_id,
      :date, :start_time, :end_time, :shift, :store,
      :store_full_address, :notes,
      :recommended, :km_custom, :hourly_rate
    )
  end
end
