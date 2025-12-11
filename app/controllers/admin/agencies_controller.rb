module Admin
  class AgenciesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin # Hérité de ApplicationController

    before_action :set_agency, only: %i[edit update destroy]

    def index
      # PUNDIT
      authorize [:admin, Agency]
      @agencies = Agency.all.order(:label)
      @agency = Agency.new
    end

    def create
      @agency = Agency.new(agency_params)
      # PUNDIT
      authorize [:admin, @agency]

      if @agency.save
        redirect_to admin_agencies_path, notice: "L'agence #{@agency.label} a été ajoutée."
      else
        # a doit recharger @agencies pour éviter un crash de la vue index
        @agencies = Agency.all.order(:label)
        flash.now[:alert] = "Erreur lors de l'ajout de l'agence."
        render :index, status: :unprocessable_entity
      end
    end

    def edit
      # PUNDIT
      authorize [:admin, @agency]
    end

    def update
      #PUNDIT
      authorize [:admin, @agency]

      if @agency.update(agency_params)
        redirect_to admin_agencies_path, notice: "L'agence #{@agency.label} a été mise à jour."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      # PUNDIT
      authorize [:admin, @agency]

      if Contract.exists?(agency: @agency.code)
         redirect_to admin_agencies_path, alert: "Impossible de supprimer : des contrats y sont liés."
      else
         @agency.destroy
         redirect_to admin_agencies_path, notice: "L'agence #{@agency.label} a été supprimée."
      end
    end

    private

    def set_agency
      @agency = Agency.find(params[:id])
    end

    def agency_params
      params.require(:agency).permit(:label, :code)
    end
  end
end
