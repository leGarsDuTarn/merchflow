# config/routes.rb
Rails.application.routes.draw do
  devise_for :users, controllers: { passwords: 'users/passwords' }

  resources :users, only: [:show]
  resources :contacts, only: [:new, :create]
  get 'confidentialite', to: 'static_pages#privacy', as: :privacy
  get 'mentions-legales', to: 'static_pages#legal_notices', as: :legal_notices
  get 'cgu', to: 'static_pages#terms', as: :terms
  get 'contact', to: 'static_pages#contact', as: :contact

  # ============================================================
  # JOB OFFERS
  # ============================================================

  resources :job_offers, only: [:index, :show, :destroy] do
    resources :job_applications, only: [:create]
  end

  # ============================================================
  # HOME + DASHBOARD
  # ============================================================
  root 'home#index'
  get 'dashboard(/:year(/:month))', to: 'dashboard#index', as: :dashboard, constraints: { year: /\d{4}/, month: /\d{1,2}/ }

  # ============================================================
  # PARAMÈTRES PRESTATAIRE (MERCH SETTINGS)
  # ============================================================
  resource :merch_settings, path: 'settings/merch', only: %i[show update] do
    patch :toggle_identity
    patch :toggle_share_address
    patch :toggle_share_planning
    patch :toggle_allow_email
    patch :toggle_allow_phone
    patch :toggle_allow_message
    patch :toggle_accept_mission_proposals
    patch :toggle_role_merch
    patch :toggle_role_anim
  end

  # ============================================================
  # WORK SESSIONS
  # ============================================================
  resources :work_sessions do
    resources :kilometer_logs, only: %i[create destroy]
  end

  # ============================================================
  # CONTRATS + WORKSESSIONS imbriqués
  # ============================================================
  resources :contracts do
    resources :work_sessions, only: %i[index new create], shallow: true
    resources :declarations, only: %i[index create]
  end

  # ============================================================
  # PLANNINGS
  # ============================================================
  resources :unavailabilities, only: %i[new create update destroy]

  # ============================================================
  # FRAIS REEL
  # ============================================================
  resources :kilometer_logs, only: [:index]

  # ============================================================
  # PROPOSAL
  # ============================================================
  resources :proposals, only: %i[index update destroy], as: :merch_proposals

  # ============================================================
  # CUSTOM ROUTES
  # ============================================================
  get 'france_travail', to: 'declarations#france_travail'
  get 'km/calc', to: 'km_api#calculate'
  get 'planning', to: 'planning#index'
  get 'communaute', to: 'static_pages#community', as: :community
  get 'mes-candidatures', to: 'job_applications#index', as: :my_applications

  # ============================================================
  # MERCH ROUTES
  # ============================================================
  scope module: :merch do
    resources :mission_proposals, only: [:update], as: :merch_mission_proposals
  end

  # ============================================================
  # FVE (force de vente externalisée)
  # ============================================================
  namespace :fve do
    get 'merch/favorites', to: 'merch#favorites', as: 'merch_favorites'

    resources :merch, only: %i[index show] do
      member do
        post :toggle_favorite
      end
    end

    get 'planning/:id', to: 'plannings#show', as: 'planning'
    get 'dashboard', to: 'dashboard#index'

    get  'invitations/:token', to: 'invitations#accept',   as: 'accept_invitation'
    post 'invitations/:token', to: 'invitations#complete', as: 'complete_invitation'

    resources :mission_proposals, only: %i[create index destroy show]
    resources :favorites, only: %i[create destroy]

    resources :job_offers do
      member do
        post :accept_candidate
        post :reject_candidate
        # --- NOUVELLES ROUTES GESTION ---
        post  :cancel_candidate # Pour annuler un recrutement
        patch :toggle_status    # Pour passer de Brouillon à Publiée
      end
    end
    resources :job_applications, only: [:destroy]
  end

  # ============================================================
  # ADMIN
  # ============================================================
  namespace :admin do
    resources :users do
      patch :toggle_premium, on: :member
      get :export_data, on: :member
    end

    resources :fve_invitations, only: %i[index new create destroy]
    resources :agencies
    get 'dashboard', to: 'dashboard#index'
  end
end
