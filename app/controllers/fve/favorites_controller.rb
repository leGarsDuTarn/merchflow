module Fve
  class FavoritesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_fve!

    def create
      # SÉCURITÉ : Vérifie si user.premium? via FavoritePolicy#create?
      authorize [:fve, Favorite]

      @merch = User.merch.find_by(id: params[:merch_id])

      unless @merch
        redirect_back fallback_location: fve_merch_index_path, alert: "Merch introuvable."
        return
      end

      favorite = current_user.favorites_given.new(merch: @merch)

      if favorite.save
        flash[:notice] = "Ajouté à votre équipe."
      else
        flash[:alert] = "Déjà dans votre équipe."
      end

      redirect_back fallback_location: fve_merch_index_path
    end

    def destroy
      @favorite = current_user.favorites_given.find_by(merch_id: params[:id])

      if @favorite
        # SÉCURITÉ : Vérifie si user.premium?
        authorize [:fve, @favorite]

        @favorite.destroy
        flash[:notice] = "Retiré de votre équipe."
      end

      redirect_back fallback_location: fve_merch_index_path
    end

    private

    def require_fve!
      redirect_to root_path, alert: "Accès refusé" unless current_user&.fve?
    end
  end
end
