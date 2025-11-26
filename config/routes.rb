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

  # ============================================================
  # ROUTING CUSTOM
  # ============================================================
  get 'france_travail', to: 'declarations#france_travail'
  get 'km/calc', to: 'km_api#calculate'
  get 'planning', to: 'planning#index'

  # ============================================
  # NAMESPACE : FVE (force de vente externalisée)
  # ============================================
  namespace :fve do
    # Liste des merch (sans données sensibles)
    resources :merch, only: %i[index show]

    # Planning d'un merch vu par la FVE
    get 'planning/:id', to: 'plannings#show', as: 'planning'

    # Acceptation d'une invitation
    get  'invitations/:token',     to: 'invitations#accept',  as: 'accept_invitation'
    post 'invitations/:token',     to: 'invitations#complete', as: 'complete_invitation'
  end
  # ============================================
  # NAMESPACE : ADMIN
  # ============================================
  namespace :admin do
    resources :users do
      member do
        patch :toggle_premium
      end
    end
    # CRUD invitation FVE côté admin
    resources :fve_invitations, only: %i[index new create destroy]

    get "dashboard", to: "dashboard#index"
  end
end
