# app/controllers/fve/favorites_controller.rb
module Fve
  class FavoritesController < ApplicationController
    before_action :authenticate_user!
    before_action :require_fve!

    def create
      # 1. On trouve le Merch (avec sécurité si ID invalide)
      @merch = User.merch.find_by(id: params[:merch_id])

      unless @merch
        redirect_back fallback_location: fve_merch_index_path, alert: "Merch introuvable."
        return
      end

      # 2. On crée le favori
      # .create ne plante pas si ça échoue, mais on peut vérifier si ça a marché
      favorite = current_user.favorites_given.new(merch: @merch)

      if favorite.save
        flash[:notice] = "Ajouté à votre équipe."
      else
        flash[:alert] = "Déjà dans votre équipe."
      end

      redirect_back fallback_location: fve_merch_index_path
    end

    def destroy
      # Note : params[:id] est l'ID du Merch (car route /favorites/:id)
      @favorite = current_user.favorites_given.find_by(merch_id: params[:id])

      if @favorite
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
