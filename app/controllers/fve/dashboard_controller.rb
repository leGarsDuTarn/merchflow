# app/controllers/fve/dashboard_controller.rb
module Fve
  class DashboardController < ApplicationController
    before_action :authenticate_user!
    before_action :verify_fve

    def index
      authorize %i[fve dashboard]
      @premium = current_user.premium?

      # --- ZONE 1 : MÉTÉO (Ce qui se passe MAINTENANT) ---
      # Logique : Uniquement ce qui est validé pour aujourd'hui.
      @missions_today_count = current_user.sent_mission_proposals
                                          .where(status: 'accepted')
                                          .where(date: Date.today)
                                          .count

      # --- ZONE 2 : PLANIFICATION (Ce qu'il faut relancer) ---
      # Logique : Tout ce qui est en attente pour AUJOURD'HUI ou le FUTUR.
      # On exclut les vieilles missions passées (date < Date.today).
      @pending_proposals_count = current_user.sent_mission_proposals
                                             .where(status: 'pending')
                                             .where('date >= ?', Date.today) # <-- AJOUT : On regarde devant nous
                                             .count

      # --- ZONE 3 : ALERTES (Ce qu'il faut re-staffer d'urgence) ---
      # Logique : Les refus pour des missions qui n'ont pas encore eu lieu (ou qui sont aujourd'hui).
      # Si une mission était hier et a été refusée, c'est trop tard, on ne l'affiche plus en alerte prioritaire.
      @alerts = current_user.sent_mission_proposals
                            .includes(:merch)
                            .where(status: 'declined')
                            .where('date >= ?', Date.today)
                            .order(updated_at: :desc)
                            .limit(3)

      # --- ZONE 4 : ÉQUIPE ---
      @favorite_merchs = current_user.try(:favorites) || []
      excluded_ids = @favorite_merchs.any? ? @favorite_merchs.pluck(:id) : []
      @other_merchs = User.merch
                          .where.not(id: excluded_ids)
                          .order(created_at: :desc)
                          .limit(9)
    end

    private

    def verify_fve
      unless current_user&.fve?
        redirect_to root_path, alert: 'Accès réservé aux forces de vente.'
      end
    end
  end
end
