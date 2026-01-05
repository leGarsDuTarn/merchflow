# app/controllers/job_offers_controller.rb
class JobOffersController < ApplicationController
  # 1. Accès libre à l'index, connexion requise pour voir les détails (show) et postuler
  before_action :authenticate_user!, except: [:index]
  before_action :set_job_offer, only: [:show]

  def index
    # On ne montre que ce qui est prêt à être vu
    @job_offers = JobOffer.published.order(start_date: :asc)

    # Filtres simples par type de mission
    if params[:filter] == 'merchandising'
      @job_offers = @job_offers.where(mission_type: 'merchandising')
    elsif params[:filter] == 'animation'
      @job_offers = @job_offers.where(mission_type: 'animation')
    end
  end

  def show
    # On initialise l'objet pour le formulaire de candidature (modal ou bas de page)
    @job_application = JobApplication.new

    # On vérifie si l'utilisateur est connecté ET s'il a déjà postulé
    # Utilisation de current_user.id pour la clarté
    @already_applied = @job_offer.job_applications.exists?(user_id: current_user.id)
  end

  private

  def set_job_offer
    # On s'assure de ne trouver que des offres existantes
    @job_offer = JobOffer.find(params[:id])

    # Sécurité supplémentaire : si un candidat essaie d'accéder à une offre "draft" via ID
    if @job_offer.status != 'published' && !current_user.fve?
      redirect_to job_offers_path, alert: "Cette offre n'est plus disponible."
    end
  end
end
