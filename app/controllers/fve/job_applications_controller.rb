module Fve
  class JobApplicationsController < ApplicationController
    before_action :authenticate_user!
    before_action :verify_fve # On réutilise ta méthode de sécurité

    def destroy
      @application = JobApplication.find(params[:id])
      authorize [:fve, @application]
      @job_offer = @application.job_offer

      # AU LIEU DE DESTROY : archive
      # Cela garde la trace en DB, donc le bouton "Déjà postulé" reste chez le Merch
      @application.update(status: 'archived')

      redirect_to fve_job_offer_path(@job_offer),
              notice: 'Candidat définitivement écarté de cette mission.',
              status: :see_other
    end

    private

    def verify_fve
      redirect_to root_path, alert: 'Accès réservé.' unless current_user&.fve?
    end
  end
end
