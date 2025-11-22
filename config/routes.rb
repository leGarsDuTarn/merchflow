Rails.application.routes.draw do
  devise_for :users

  root 'home#index'
  get 'dashboard', to: 'dashboard#index'

  # ============================================================
  # 1. ROUTES SPÉCIFIQUES 
  # ============================================================
  # Cette route attrape /work_sessions/new AVANT que le 'show' ne s'active
  resources :work_sessions, only: %i[new create index]

  # ============================================================
  # 2. CONTRATS + WORKSESSIONS (shallow)
  # ============================================================
  resources :contracts do
    # Le shallow va générer les routes /work_sessions/:id (show, edit, update, destroy)
    resources :work_sessions, shallow: true
    resources :declarations, only: %i[index create]
  end

  # ============================================================
  # KILOMETER LOGS
  # ============================================================
  resources :work_sessions, only: [] do
    resources :kilometer_logs, only: %i[create destroy]
  end

  get 'france_travail', to: 'declarations#france_travail'
  get 'km/calc', to: 'km_api#calculate'
end
