# frozen_string_literal: true

Rails.application.routes.draw do
  # ============================================================
  # DEVISE AUTH
  # ============================================================
  devise_for :users

  # ============================================================
  # HOME & DASHBOARD
  # ============================================================
  root 'home#index'
  get 'dashboard', to: 'dashboard#index'

  # ============================================================
  # CONTRATS + WORKSESSIONS (shallow routing)
  # ============================================================
  resources :contracts do
    resources :work_sessions, shallow: true
    resources :declarations, only: %i[index create]
  end

  # ➜ Permet /work_sessions/new (création depuis dashboard)
  resources :work_sessions, only: [:new, :create, :index]

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
  # API Google Distance
  # ============================================================
  get 'km/calc', to: 'km_api#calculate'
end
