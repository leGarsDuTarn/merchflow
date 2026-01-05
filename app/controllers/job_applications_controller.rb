class JobApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_job_offe, only: [:create]

  def index
    # On récupère toutes les candidatures du Merch
    # On inclut l'offre et l'utilisateur FVE pour afficher le nom de l'agence/client
    @job_applications = current_user.job_applications
                                    .includes(job_offer: :fve)
                                    .order(created_at: :desc)
  end

  def create
    # 1. Construit la candidature
    @job_application = @job_offer.job_applications.build(job_application_params)

    # 2. Lie au candidat connecté (merch_id dans ta DB)
    @job_application.merch = current_user
    @job_application.status = 'pending'

    if @job_application.save
      redirect_to job_offer_path(@job_offer), notice: "Votre candidature a bien été envoyée ! 🚀"
    else
      # En cas d'erreur (ex: déjà postulé), redirige vers l'offre avec le message d'erreur
      redirect_to job_offer_path(@job_offer), alert: @job_application.errors.full_messages.to_sentence
    end
  end

  private

  def set_job_offer
    @job_offer = JobOffer.find(params[:job_offer_id])
  end

  def job_application_params
    # Autorise le message s'il y en a un, sinon permet un hash vide
    params.require(:job_application).permit(:message) if params[:job_application].present?
  end
end
