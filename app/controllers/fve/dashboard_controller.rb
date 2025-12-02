# app/controllers/fve/dashboard_controller.rb
module Fve
  class DashboardController < ApplicationController
    before_action :authenticate_user!
    before_action :verify_fve

    def index
      authorize %i[fve dashboard]

      # Statistiques générales
      @total_merch = User.merch.count
      @premium = current_user.premium?

      # 1. Missions Proposées par cet utilisateur FVE (Sent Mission Proposals)
      # On compte le nombre total de propositions que cette agence FVE a envoyées.
      @total_proposals_sent = current_user.sent_mission_proposals.count

      # 2. Statut des Propositions
      # Montre l'état actuel des missions proposées par cet FVE
      @pending_proposals = current_user.sent_mission_proposals.where(status: :pending).count
      @accepted_proposals = current_user.sent_mission_proposals.where(status: :accepted).count

      # 3. Contrats actifs
      # Compte le nombre de prestataires qui ont un contrat avec l'agence du FVE
      @merch_with_contracts = User.merch
                                  .joins(:contracts)
                                  .where(contracts: { agency: current_user.agency })
                                  .distinct
                                  .count

      # 4. Utilisateurs Merch récents (pour la vue)
      @merch_users = User.merch.order(created_at: :desc).limit(10)
    end

    private

    def verify_fve
      unless current_user&.fve?
        redirect_to root_path, alert: 'Accès réservé aux forces de vente.'
      end
    end
  end
end
