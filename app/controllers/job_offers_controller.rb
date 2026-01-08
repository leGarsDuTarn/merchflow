# app/controllers/job_offers_controller.rb
class JobOffersController < ApplicationController
  # 1. Accès libre à l'index, connexion requise pour voir les détails (show) et postuler
  before_action :authenticate_user!, except: [:index]
  before_action :set_job_offer, only: [:show]

 def index
    @job_offers = JobOffer.published
                          .upcoming
                          .by_query(params[:city])     # Recherche texte (Ville/Zip)
                          .by_department(params[:department])
                          .by_type(params[:type])
                          .by_contract(params[:contract_type])
                          .min_rate(params[:min_rate])
                          .starting_after(params[:start_date])
                          .order(start_date: :asc)
 end

  def show
    # On initialise l'objet pour le formulaire de candidature
    @job_application = JobApplication.new

    # Sécurité : On vérifie si l'user est connecté avant de checker sa candidature
    # afin d'éviter un crash pour les visiteurs non-connectés
    @already_applied = if current_user
                         @job_offer.job_applications.exists?(merch_id: current_user.id)
                       else
                         false
                       end
  end

  private

  def set_job_offer
    # On récupère l'offre
    @job_offer = JobOffer.find(params[:id])

    # Sécurité supplémentaire : si un candidat tente d'accéder à un brouillon (draft) via ID
    # Seul l'auteur (FVE) ou un admin peut voir une offre non publiée
    if @job_offer.status != 'published' && (current_user.nil? || !current_user.fve?)
      redirect_to job_offers_path, alert: "Cette offre n'est plus disponible."
    end
  end
end
