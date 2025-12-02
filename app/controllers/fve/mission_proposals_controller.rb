# app/controllers/fve/mission_proposals_controller.rb
module Fve 
  class MissionProposalsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_fve!

    def create
      @proposal = MissionProposal.new(proposal_params)
      @proposal.fve = current_user
      @proposal.agency = current_user.agency

      # 1. Trouver le Merch (ID est dans les paramètres forts de la proposition)
      @merch_user = User.find_by(id: @proposal.merch_id)

      # 2. Vérification de l'existence du prestataire
      unless @merch_user
        return redirect_back fallback_location: fve_merch_index_path, alert: 'Prestataire cible introuvable.'
      end

      @proposal.merch = @merch_user # Lier l'objet trouvé

      # --- 3. VERIFICATION DU CONTRAT (Contrainte : Contrat avec l'Agence du FVE) ---
      agency_name = current_user.agency # Récupère le nom de l'agence du FVE connecté

      unless @merch_user.contracts.exists?(agency: agency_name)
        return redirect_back fallback_location: fve_merch_path(@merch_user),
                             alert: "Action refusée : Le prestataire doit avoir un contrat actif avec votre agence (#{agency_name.capitalize})."
      end

      # --- 4. VERIFICATION DE LA DISPONIBILITÉ (Contrainte Requise) ---
      if is_merch_unavailable?(@merch_user, @proposal.date, @proposal.start_time, @proposal.end_time)
        return redirect_back fallback_location: fve_merch_path(@merch_user),
                             alert: "Action refusée : Le prestataire n'est pas disponible à cette date/heure (conflit de planning ou indisponibilité personnelle)."
      end

      # 5. Sauvegarde
      @proposal.status = :pending

      if @proposal.save
        # TODO: Ajouter ici l'envoi de notification (SMS/Email) au Merch
        redirect_to fve_merch_path(@merch_user), notice: 'Proposition envoyée avec succès ! En attente de la réponse du Merch.'
      else
        # Si les validations du modèle MissionProposal échouent
        redirect_to fve_merch_path(@merch_user), alert: "Erreur lors de la proposition : #{@proposal.errors.full_messages.join(', ')}"
      end
    end

    private

    def require_fve!
      redirect_to root_path, alert: 'Accès réservé aux FVE' unless current_user&.fve?
    end

    # Logique de vérification de la disponibilité du prestataire
    def is_merch_unavailable?(merch_user, date, start_time, end_time)
      # Vérifie si la date est dans les indisponibilités personnelles
      is_unavailable_personally = merch_user.unavailabilities.exists?(date: date)
      return true if is_unavailable_personally

      # Vérifie les sessions de travail planifiées (WorkSession) pour le chevauchement
      # Utilisation du scope :overlapping que nous avons ajouté au modèle WorkSession
      is_booked = merch_user.work_sessions
                            .overlapping(start_time, end_time)
                            .exists?

      return true if is_booked

      return false
    end

    def proposal_params
      params.require(:mission_proposal).permit(
        :merch_id,
        :date,
        :start_time,
        :end_time,
        :company,
        :store_name,
        :store_address,
        :hourly_rate,
        :message
      )
    end
  end
end
