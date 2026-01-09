class JobApplicationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_job_offer, only: [:create]

  def index
    @job_applications = current_user.job_applications
                                    .includes(job_offer: :fve)
                                    .order(created_at: :desc)

    # --- LOGIQUE DE FILTRAGE (France Travail) ---
    if params[:search].present?
      @job_applications = @job_applications.by_status(params[:search][:status]) if params[:search][:status].present?
      @job_applications = @job_applications.by_month(params[:search][:month])   if params[:search][:month].present?
      @job_applications = @job_applications.by_year(params[:search][:year])     if params[:search][:year].present?
    end

      respond_to do |format|
        format.html # Affiche la vue normale
        format.pdf do
         # On instancie notre classe PDF
        pdf = ProofPdf.new(@job_applications, current_user)

        # On envoie le fichier au navigateur
        send_data pdf.render,
                filename: "recap_candidatures_#{current_user.firstname}_#{Date.today}.pdf",
                type: 'application/pdf',
                disposition: 'attachment' # 'inline' pour voir dans le navigateur sans télécharger
    end
    end
  end

  def create
    @job_application = @job_offer.job_applications.build(job_application_params)
    @job_application.merch = current_user
    @job_application.status = 'pending'

    if @job_application.save
      redirect_to job_offer_path(@job_offer), notice: "Votre candidature a bien été envoyée ! 🚀"
    else
      redirect_to job_offer_path(@job_offer), alert: @job_application.errors.full_messages.to_sentence
    end
  end

  def destroy
    @application = current_user.job_applications.find(params[:id])
    @application.destroy

    # Redirection intelligente :
    # Si on vient de la liste "Mes candidatures", on y reste.
    # Sinon on retourne à l'offre.
    if request.referer&.include?(my_applications_path)
      redirect_to my_applications_path, notice: "Candidature supprimée de votre historique.", status: :see_other
    else
      redirect_to job_offer_path(@application.job_offer), notice: "Candidature annulée.", status: :see_other
    end
  end

  private

  def set_job_offer
    @job_offer = JobOffer.find(params[:job_offer_id])
  end

  def job_application_params
    params.require(:job_application).permit(:message) if params[:job_application].present?
  end
end
