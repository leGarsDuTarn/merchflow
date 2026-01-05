# app/services/recruit_merch_service.rb
class RecruitMerchService
  attr_reader :error_message

  def initialize(job_application)
    @application = job_application
    @offer       = job_application.job_offer
    @merch       = job_application.merch # Le candidat (User)
    @fve         = @offer.fve           # Le recruteur (User)
  end

  def call
    # 1. Sécurité anti-doublon immédiate
    if @application.status == 'accepted'
      @error_message = "Ce candidat a déjà été recruté pour cette mission."
      return false
    end

    ActiveRecord::Base.transaction do
      # 2. Gestion du Contrat (Le point critique avec ton Model)
      contract = find_or_create_contract

      # 3. Création des sessions (Boucle temporelle)
      create_work_sessions_loop(contract)

      # 4. Validation finale de la candidature
      @application.update!(status: 'accepted')
    end

    true
  rescue ActiveRecord::RecordInvalid => e
    # Capture les erreurs de validation du modèle Contract (ex: Agence invalide)
    @error_message = "Erreur de validation : #{e.record.errors.full_messages.join(', ')}"
    false
  rescue StandardError => e
    @error_message = "Une erreur inattendue est survenue : #{e.message}"
    false
  end

  private

  def find_or_create_contract
    # On cherche un contrat existant pour ce couple
    existing = Contract.find_by(merch_id: @merch.id, fve_id: @fve.id)
    return existing if existing.present?

    # --- Préparation des données pour le Modèle Contract ---

    # A. Gestion de l'Agence (CRITIQUE pour validate :agency_must_exist_in_db)
    # On récupère l'agence du FVE, sinon on prend la première agence valide en base
    # pour éviter le crash.
    agency_code = @fve.respond_to?(:agency) ? @fve.agency : nil

    unless Agency.exists?(code: agency_code)
      # Fallback : Si l'agence du FVE est vide ou invalide, on doit en assigner une valide
      # Option 1 : On prend la première de la liste
      # Option 2 : On lève une erreur explicite (choisi ici pour la sécurité)
      raise StandardError, "Le profil du FVE n'a pas d'agence valide associée. Impossible de créer le contrat."
    end

    # B. Gestion du type de contrat (Enum)
    # On s'assure que le type correspond bien aux clés :cdd, :cidd, :interim
    c_type = @offer.contract_type.to_s.downcase
    unless Contract.contract_types.keys.include?(c_type)
      c_type = 'cdd' # Valeur par défaut si le type de l'offre est malformé
    end

    # C. Calcul des taux (IFM/CP)
    # Ton controller divise par 100, ici on applique la logique métier directe
    is_precarious = %w[cdd cidd interim].include?(c_type)
    rate = is_precarious ? 0.10 : 0.0

    # --- Création ---
    Contract.create!(
      name: "Contrat #{@offer.mission_type} - #{@offer.company_name}",

      # Relations (Tu as belongs_to :user ET belongs_to :merch)
      user: @merch,        # Propriétaire du contrat
      merch: @merch,       # Relation explicite
      fve: @fve,           # Responsable

      # Données validées
      agency: agency_code,
      contract_type: c_type,

      # Financier (valeurs brutes pour le modèle, ex: 0.1 pour 10%)
      night_rate: @offer.night_rate || 0,
      ifm_rate: rate,
      cp_rate: rate,

      # Kilométrique
      km_rate: @offer.km_rate || 0.25, # Valeur par défaut safe
      km_limit: @offer.km_unlimited ? 0 : (@offer.km_limit || 0),
      km_unlimited: @offer.km_unlimited || false
    )
  end

  def create_work_sessions_loop(contract)
    start_date = @offer.start_date.to_date
    end_date   = @offer.end_date.to_date

    (start_date..end_date).each do |current_date|
      # Construction robuste des heures avec .change
      daily_start = current_date.to_time.change(hour: @offer.start_date.hour, min: @offer.start_date.min)
      daily_end   = current_date.to_time.change(hour: @offer.end_date.hour, min: @offer.end_date.min)

      # Gestion des pauses
      daily_break_start, daily_break_end = nil, nil
      if @offer.break_start_time && @offer.break_end_time
        daily_break_start = current_date.to_time.change(hour: @offer.break_start_time.hour, min: @offer.break_start_time.min)
        daily_break_end   = current_date.to_time.change(hour: @offer.break_end_time.hour, min: @offer.break_end_time.min)
      end

      # Gestion Nuit (Si fin < début, c'est le lendemain)
      daily_end += 1.day if daily_end <= daily_start

      # Gestion Nuit Pause (Si fin pause < début pause)
      if daily_break_start && daily_break_end <= daily_break_start
        daily_break_end += 1.day
      end

      WorkSession.create!(
        contract: contract,
        date: current_date,
        start_time: daily_start,
        end_time: daily_end,
        break_start_time: daily_break_start,
        break_end_time: daily_break_end,
        hourly_rate: @offer.hourly_rate,
        company: @offer.company_name,
        store: @offer.store_name,
        store_full_address: [@offer.address, @offer.zipcode, @offer.city].compact.join(', '),
        status: 'accepted'
      )
    end
  end
end
