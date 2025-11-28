Rails.application.routes.draw do
  devise_for :users

  # HOME + DASHBOARD
  root 'home#index'
  get 'dashboard', to: 'dashboard#index'
  patch 'dashboard/privacy', to: 'dashboard#update_privacy', as: 'dashboard_privacy'

  # ============================================================
  # WORK SESSIONS (création globale + toutes les actions)
  # ============================================================
  resources :work_sessions do
    resources :kilometer_logs, only: %i[create destroy]
  end

  # ============================================================
  # CONTRATS + WORKSESSIONS imbriqués (shallow: true)
  # ============================================================
  resources :contracts do
    # On ne redéfinit que index, new, create pour les routes imbriquées
    # Les autres actions (show, edit, update, destroy) sont gérées par la route globale
    resources :work_sessions, only: %i[index new create], shallow: true
    resources :declarations, only: %i[index create]
  end

  # ============================================================
  # PLANNINGS
  # ============================================================
  resources :unavailabilities, only: %i[new create update destroy]

  # ============================================================
  # CUSTOM ROUTES
  # ============================================================
  get 'france_travail', to: 'declarations#france_travail'
  get 'km/calc', to: 'km_api#calculate'
  get 'planning', to: 'planning#index'

  # ============================================================
  # FVE (force de vente externalisée)
  # ============================================================
  namespace :fve do
    resources :merch, only: %i[index show]
    get 'planning/:id', to: 'plannings#show', as: 'planning'
    get 'dashboard', to: 'dashboard#index'

    # Invitations FVE
    get  'invitations/:token', to: 'invitations#accept',   as: 'accept_invitation'
    post 'invitations/:token', to: 'invitations#complete', as: 'complete_invitation'
  end

  # ============================================================
  # ADMIN
  # ============================================================
  namespace :admin do
    resources :users do
      patch :toggle_premium, on: :member
    end

    resources :fve_invitations, only: %i[index new create destroy]

    get 'dashboard', to: 'dashboard#index'
  end
end
