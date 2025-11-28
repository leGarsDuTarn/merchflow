class UnavailabilitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_unavailability, only: [:update, :destroy]

  # =========================================================
  # CREATE
  # =========================================================
  def create
    # 1. On récupère la date peu importe comment elle arrive
    raw_date = params[:date] ||
               params[:start_date] ||
               (params[:unavailability] && params[:unavailability][:date])

    if raw_date.blank?
      redirect_to planning_path, alert: "Date invalide." and return
    end

    date = Date.parse(raw_date.to_s)

    # 2. Création ou mise à jour
    unav = current_user.unavailabilities.find_or_initialize_by(date: date)

    # On récupère la note (gère le cas imbriqué ou direct)
    note_content = params[:notes] || (params[:unavailability] && params[:unavailability][:notes])
    unav.notes = note_content

    if unav.save
      # CORRECTION ICI : On envoie year et month au PlanningController
      redirect_to planning_path(year: date.year, month: date.month), notice: "Indisponibilité enregistrée."
    else
      redirect_to planning_path(year: date.year, month: date.month), alert: "Impossible d'enregistrer."
    end
  end

  # =========================================================
  # UPDATE
  # =========================================================
  def update
    # On garde la date en mémoire pour la redirection
    target_date = @unavailability.date

    note_content = params[:notes] || (params[:unavailability] && params[:unavailability][:notes])

    if @unavailability.update(notes: note_content)
      redirect_to planning_path(year: target_date.year, month: target_date.month), notice: "Mise à jour effectuée."
    else
      redirect_to planning_path(year: target_date.year, month: target_date.month), alert: "Erreur de mise à jour."
    end
  end

  # =========================================================
  # DESTROY
  # =========================================================
  def destroy
    # IMPORTANT : On capture la date AVANT de supprimer
    target_date = @unavailability.date

    @unavailability.destroy

    # On redirige vers l'année et le mois de l'indisponibilité supprimée
    redirect_to planning_path(year: target_date.year, month: target_date.month), notice: "Jour rendu disponible."
  end

  private

  def set_unavailability
    @unavailability = current_user.unavailabilities.find(params[:id])
  end
end
