class UnavailabilitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_unavailability, only: [:update, :destroy]

  # =========================================================
  # CREATE — Créer une indispo pour un jour précis
  # =========================================================
  def create
    # On accepte soit params[:date], soit params[:start_date]
    raw_date = params[:date] || params[:start_date]

    if raw_date.blank?
      redirect_to planning_path, alert: "Date invalide." and return
    end

    date = Date.parse(raw_date)

    unav = current_user.unavailabilities.find_or_initialize_by(date: date)
    unav.notes = params[:notes]
    unav.save!

    redirect_to planning_path, notice: "Indisponibilité enregistrée."
  end

  # =========================================================
  # UPDATE — Modifier uniquement la note
  # =========================================================
  def update
    @unavailability.update!(notes: params[:notes])
    redirect_to planning_path, notice: "Indisponibilité mise à jour."
  end

  # =========================================================
  # DESTROY — Rendre disponible
  # =========================================================
  def destroy
    @unavailability.destroy
    redirect_to planning_path, notice: "Jour rendu disponible."
  end

  private

  def set_unavailability
    @unavailability = current_user.unavailabilities.find(params[:id])
  end
end
