# app/controllers/fve/dashboard_controller.rb
module Fve
  class DashboardController < ApplicationController
    before_action :authenticate_user!
    before_action :verify_fve

    def index
      authorize %i[fve dashboard]
      @premium = current_user.premium?

      # --- ZONE 1 : MÉTÉO (KPIs) ---

      # CORRECTION ICI : On utilise directement le champ "date" de la proposition
      @missions_today_count = current_user.sent_mission_proposals
                                          .where(status: 'accepted') # ou :accepted si enum
                                          .where(date: Date.today)
                                          .count

      @pending_proposals_count = current_user.sent_mission_proposals
                                             .where(status: 'pending')
                                             .count

      # --- ZONE 2 : ALERTES (Refus) ---

      # CORRECTION ICI : On retire :mission du includes car il n'existe pas
      @alerts = current_user.sent_mission_proposals
                            .includes(:merch) # On garde merch pour éviter les requêtes N+1
                            .where(status: 'refused')
                            .order(updated_at: :desc)
                            .limit(5)

      # --- ZONE 3 : ÉQUIPE ---

      # Si tu as mis en place les favoris :
      @favorite_merchs = current_user.try(:favorites) || []

      # Les autres (exclure les favoris)
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
