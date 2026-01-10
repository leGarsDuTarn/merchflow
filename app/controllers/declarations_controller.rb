class DeclarationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_contract, only: %i[index create]

  # ============================================
  # FRANCE TRAVAIL (global, tous employeurs)
  # ============================================
  def france_travail
    # 1. Gestion de la Date (Mois/Année)
    if params[:date].present?
      parsed = Date.parse("#{params[:date]}-01")
      @year  = parsed.year
      @month = parsed.month
    else
      @year  = (params[:year]  || Date.today.year).to_i
      @month = (params[:month] || Date.today.month).to_i
    end

    # Normalisation des mois (ex: mois 13 => mois 1 année N+1)
    if @month < 1
      @month = 12
      @year -= 1
    end

    if @month > 12
      @month = 1
      @year += 1
    end

    # 2. Récupération des sessions du mois
    @sessions = current_user.work_sessions.for_month(@year, @month)

    # 3. Groupement et TRI ALPHABÉTIQUE par agence
    # On trie sur le nom de l'agence (agency) pour que le PDF et la vue soient ordonnés
    @grouped = @sessions.group_by { |ws| ws.contract.agency }
                        .sort_by { |agency, _| agency.to_s.downcase }
                        .to_h

    # 4. Formats de réponse (HTML ou PDF)
    respond_to do |format|
      format.html # Affiche la vue normale
      format.pdf do
        pdf = FranceTravailPdf.new(@grouped, current_user, @month, @year)
        send_data pdf.render,
                  filename: "declaration_france_travail_#{@month}_#{@year}.pdf",
                  type: 'application/pdf',
                  disposition: 'attachment' # 'inline' pour voir dans le navigateur
      end
    end
  end

  # ============================================
  # DÉCLARATIONS PAR CONTRAT
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
