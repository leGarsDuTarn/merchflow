# app/controllers/fve/dashboard_controller.rb
module Fve
  class DashboardController < ApplicationController
    before_action :authenticate_user!
    before_action :verify_fve

    def index
      authorize %i[fve dashboard]

      @premium = current_user.premium?

      # 1. Récupération des Merchs favoris (objets User) pour la section "Mon Équipe"
      #    On inclut les paramètres pour éviter les requêtes N+1 sur les cartes (includes(:merch_setting)).
      @favorite_merchs = current_user.favorite_merchs.includes(:merch_setting)

      # 2. On récupère les IDs des Merchs déjà en favoris pour les exclure de la section "Découverte"
      excluded_ids = @favorite_merchs.pluck(:id)

      # 3. Récupération des autres Merchs (non favoris) pour la section "Découverte/Suggestions"
      #    On utilise le scope User.merch (si défini) ou User.where(role: X)
      @other_merchs = User.merch
                          .where.not(id: excluded_ids)
                          .includes(:merch_setting)
                          .order(created_at: :desc)
                          .limit(3) # Limité à 9 pour un affichage propre

    end

    private

    def verify_fve
      unless current_user&.fve?
        redirect_to root_path, alert: 'Accès réservé aux forces de vente.'
      end
    end
  end
end
