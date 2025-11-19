# frozen_string_literal: true

Rails.application.routes.draw do
  # ============================================================
  # DEVISE AUTHENTICATION
  # ============================================================
  devise_for :users

  # ============================================================
  # DASHBOARD
  # ============================================================

  # Landing page publique -> pas de before_action :authenticate_user!
  root 'home#index'
  # Dashboard après login
  get 'dashboard', to: 'dashboard#index'

  # ============================================================
  # CONTRATS + WORKSESSIONS (shallow routing)
  # ============================================================
  resources :contracts do
    # Shallow = évite les URL trop longues pour les actions qui n’ont pas besoin du parent.
    resources :work_sessions, shallow: true
    resources :declarations, only: %i[index create]
  end

  resources :work_sessions, only: [:index]

  # ============================================================
  # KILOMETER LOGS (lié à une work_session)
  # ============================================================
  resources :work_sessions, only: [] do
    resources :kilometer_logs, only: %i[create destroy]
  end

  # ============================================================
  # DECLARATIONS FRANCE TRAVAIL (vue globale)
  # ============================================================
  get 'france_travail', to: 'declarations#france_travail'

  # ============================================================
  # API Google Distance (optionnel)
  # ============================================================
  get 'km/calc', to: 'km_api#calculate'
end
