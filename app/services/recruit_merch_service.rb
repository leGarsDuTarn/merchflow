class RecruitMerchService
  attr_reader :error_message

  def initialize(job_application)
    @application = job_application
    @offer       = job_application.job_offer

    # CORRECTION : On s'assure d'appeler .merch (comme défini dans ton modèle JobApplication)
    @merch       = job_application.merch
    @fve         = @offer.fve
  end

  def call
    # 1. Sécurité anti-doublon
    if @application.status == 'accepted'
      @error_message = "Ce candidat a déjà été recruté pour cette mission."
      return false
    end

    ActiveRecord::Base.transaction do
      # 2. Gestion du Contrat
      contract = find_or_create_contract

      # 3. Création des sessions de travail
      create_work_sessions_loop(contract)

      # 4. Validation finale de la candidature
      @application.update!(status: 'accepted')
    end

    true
  rescue ActiveRecord::RecordInvalid => e
    # Capture les erreurs de validation (ex: Agence invalide, dates manquantes)
    @error_message = "Erreur de validation : #{e.record.errors.full_messages.join(', ')}"
    false
  rescue StandardError => e
    @error_message = "Une erreur inattendue est survenue : #{e.message}"
    false
  end

  private

  def find_or_create_contract
    # On cherche un contrat existant pour ce couple Merch/FVE
    existing = Contract.find_by(merch_id: @merch.id, fve_id: @fve.id)
    return existing if existing.present?

    # --- Préparation des données ---

    # A. Gestion de l'Agence
    agency_code = @fve.respond_to?(:agency) ? @fve.agency : nil

    unless Agency.exists?(code: agency_code)
      raise StandardError, "Le profil du FVE n'a pas d'agence valide associée. Impossible de créer le contrat."
    end

    # B. Type de contrat
    c_type = @offer.contract_type.to_s.downcase
    unless Contract.contract_types.keys.include?(c_type)
      c_type = 'cdd' # Valeur par défaut safe
    end

    # C. Calcul des taux (IFM/CP)
    is_precarious = %w[cdd cidd interim].include?(c_type)
    rate = is_precarious ? 0.10 : 0.0

    # --- Création ---
    Contract.create!(
      name: "Mission #{@offer.mission_type.capitalize} - #{@offer.company_name}",

      # Relations clés
      user: @merch,        # Le propriétaire du contrat est le Merch
      merch: @merch,       # Relation explicite
      fve: @fve,           # Le FVE responsable

      # Données
      agency: agency_code,
      contract_type: c_type,

      # Financier
      night_rate: @offer.night_rate || 0,
      ifm_rate: rate,
      cp_rate: rate,

      # Kilométrique
      km_rate: @offer.km_rate || 0.25,
      km_limit: @offer.km_unlimited ? 0 : (@offer.km_limit || 0),
      km_unlimited: @offer.km_unlimited || false
    )
  end

  def create_work_sessions_loop(contract)
    start_date = @offer.start_date.to_date
    end_date   = @offer.end_date.to_date

    (start_date..end_date).each do |current_date|
      # Construction robuste des horaires
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

      # Gestion Nuit Pause
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

        # Le statut 'accepted' fait apparaitre la mission dans le planning du Merch
        status: 'accepted'
      )
    end
  end
end
