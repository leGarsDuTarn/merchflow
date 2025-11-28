class UnavailabilitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_unavailability, only: :destroy

  # =======================================
  # NEW – Formulaire pour choisir une période
  # =======================================
  def new
    # Juste un formulaire simple
  end

  # =======================================
  # CREATE – Enregistre une plage de dates
  # =======================================
  def create
    start_date = Date.parse(params[:start_date])
    end_date   = Date.parse(params[:end_date])

    (start_date..end_date).each do |day|
      current_user.unavailabilities.find_or_create_by(date: day) do |u|
        u.notes = params[:notes]
      end
    end

    redirect_to planning_path, notice: 'Indisponibilité enregistrée.'
  end

  # =======================================
  # UPDATE – Modifie une plage de dates
  # =======================================

  def update
    @unavailability = current_user.unavailabilities.find(params[:id])
    @unavailability.update(notes: params[:notes])

    redirect_to planning_path, notice: 'Indisponibilité modifiée.'
  end


  # =======================================
  # DESTROY – Re rendre un jour disponible
  # =======================================
  def destroy
    @unavailability.destroy
    redirect_to planning_path, notice: 'Jour marqué comme disponible.'
  end

  private

  def set_unavailability
    @unavailability = current_user.unavailabilities.find(params[:id])
  end
end
