Rails.application.routes.draw do
  devise_for :users

  # HOME + DASHBOARD
  root 'home#index'
  get 'dashboard', to: 'dashboard#index'
  patch 'dashboard/privacy', to: 'dashboard#update_privacy'

  # ============================================================
  # WORK SESSIONS (création globale)
  # ============================================================
  resources :work_sessions, only: %i[new create index] do
    resources :kilometer_logs, only: %i[create destroy]
  end

  # ============================================================
  # CONTRATS + WORKSESSIONS (shallow)
  # ============================================================
  resources :contracts do
    resources :work_sessions, shallow: true
    resources :declarations, only: %i[index create]
  end

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
    get  'planning/:id', to: 'plannings#show', as: 'planning'

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
