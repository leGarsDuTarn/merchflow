module Fve
  class JobApplicationsController < ApplicationController
    before_action :authenticate_user!
    before_action :verify_fve # On réutilise ta méthode de sécurité

    def destroy
      @application = JobApplication.find(params[:id])
      # On vérifie que c'est bien l'offre du FVE connecté
      if @application.job_offer.fve == current_user
        @application.destroy
        redirect_to fve_job_offer_path(@application.job_offer), notice: 'Candidature supprimée.', status: :see_other
      else
        redirect_to root_path, alert: 'Action non autorisée.'
      end
    end

    private

    def verify_fve
      redirect_to root_path, alert: 'Accès réservé.' unless current_user&.fve?
    end
  end
end
