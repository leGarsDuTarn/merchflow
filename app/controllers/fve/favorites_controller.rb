module Fve
  class FavoritesController < ApplicationController
    before_action :authenticate_user! # Si tu utilises Devise

    def create
      # Récupère le merch via le paramètre envoyé par le bouton
      @merch = User.find(params[:merch_id])

      # Création du favori
      current_user.favorites_given.create(merch: @merch)

      # Redirection fluide (reste sur la même page)
      redirect_back fallback_location: fve_merch_index_path
    end

    def destroy
      # Dans l'URL 'DELETE /fve/favorites/:id', le paramètre :id contient l'ID du Merch
      # Cherche donc le favori qui correspond à CE merch pour CET utilisateur
      @favorite = current_user.favorites_given.find_by(merch_id: params[:id])

      @favorite&.destroy

      redirect_back fallback_location: fve_merch_index_path
    end
  end
end
