module Admin
  class AgenciesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin

    before_action :set_agency, only: %i[edit update destroy]

    def index
      @agencies = Agency.all.order(:label)
      @agency = Agency.new # Pour le formulaire de création
    end

    def create
      @agency = Agency.new(agency_params)
      if @agency.save
        redirect_to admin_agencies_path, notice: "L'agence #{@agency.label} a été ajoutée."
      else
        @agencies = Agency.all.order(:label)
        flash.now[:alert] = "Erreur lors de l'ajout de l'agence."
        render :index, status: :unprocessable_entity
      end
    end

    def edit
      # L'agence est chargée via set_agency
    end

    def update
      if @agency.update(agency_params)
        redirect_to admin_agencies_path, notice: "L'agence #{@agency.label} a été mise à jour."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      # Vérification optionnelle : empêcher la suppression si des contrats y sont liés
      if Contract.exists?(agency: @agency.code)
         redirect_to admin_agencies_path, alert: "Impossible de supprimer l'agence #{@agency.label} : des contrats y sont encore liés."
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
      # Autorise l'édition du label. Le code est géré par before_validation si laissé vide.
      params.require(:agency).permit(:label, :code)
    end
  end
end
