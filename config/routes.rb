# config/routes.rb
Rails.application.routes.draw do
  devise_for :users

  resources :users, only: [:show]

  # ============================================================
  # HOME + DASHBOARD
  # ============================================================
  root 'home#index'
  # Ajout des paramètres optionnels pour la navigation historique (Merch Dashboard)
  get 'dashboard(/:year(/:month))', to: 'dashboard#index', as: :dashboard, constraints: { year: /\d{4}/, month: /\d{1,2}/ }

  # NOTE: La route dashboard/privacy était obsolète et n'est plus nécessaire.
  # patch 'dashboard/privacy', to: 'dashboard#update_privacy', as: 'dashboard_privacy'

  # ============================================================
  # PARAMÈTRES PRESTATAIRE (MERCH SETTINGS)
  # ============================================================
  resource :merch_settings, path: 'settings/merch', only: %i[show update] do
    # Routes spécifiques pour les toggles (basculement rapide par POST)
    post :toggle_identity
    post :toggle_share_address
    post :toggle_share_planning
    post :toggle_allow_email
    post :toggle_allow_phone
    post :toggle_allow_message
    post :toggle_accept_mission_proposals
    post :toggle_role_merch
    post :toggle_role_anim
  end

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
    resources :work_sessions, only: %i[index new create], shallow: true
    resources :declarations, only: %i[index create]
  end

  # ============================================================
  # PLANNINGS
  # ============================================================
  resources :unavailabilities, only: %i[new create update destroy]

  # ============================================================
  # PROPOSAL
  # ============================================================
  resources :proposals, only: %i[index update destroy], as: :merch_proposals
  # ============================================================
  # CUSTOM ROUTES
  # ============================================================
  get 'france_travail', to: 'declarations#france_travail'
  get 'km/calc', to: 'km_api#calculate'
  get 'planning', to: 'planning#index' # Planning côté Merch

  # ============================================================
  # MERCH ROUTES (Actions du Prestataire)
  # ============================================================
  # Géré par Merch::MissionProposalsController
  scope module: :merch do
    resources :mission_proposals, only: [:update], as: :merch_mission_proposals

  end

  # ============================================================
  # FVE (force de vente externalisée)
  # ============================================================
  namespace :fve do
    get 'merch/favorites', to: 'merch#favorites', as: 'merch_favorites'

    resources :merch, only: %i[index show]

    get 'planning/:id', to: 'plannings#show', as: 'planning'
    get 'dashboard', to: 'dashboard#index'

    get  'invitations/:token', to: 'invitations#accept',   as: 'accept_invitation'
    post 'invitations/:token', to: 'invitations#complete', as: 'complete_invitation'

    resources :mission_proposals, only: %i[create index destroy show]
    resources :favorites, only: %i[create destroy]
  end

  # ============================================================
  # ADMIN
  # ============================================================
  namespace :admin do
    resources :users do
      patch :toggle_premium, on: :member
    end

    resources :fve_invitations, only: %i[index new create destroy]
    # Routes CRUD pour la gestion des agences
    resources :agencies

    get 'dashboard', to: 'dashboard#index'
  end
end
