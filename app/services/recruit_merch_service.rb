class RecruitMerchService
  def initialize(job_application)
    @application = job_application
    @offer       = job_application.job_offer
    @merch       = job_application.merch # On utilise la relation 'merch'
    @fve         = @offer.fve
  end

  def call
    ActiveRecord::Base.transaction do
      # 1. Vérifier ou Créer le Contrat Cadre
      contract = find_or_create_contract

      # 2. Créer les sessions de travail (Boucle jour par jour)
      create_work_sessions_loop(contract)

      # 3. Valider la candidature
      @application.update!(status: 'accepted')
    end

    return true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("Erreur RecruitMerchService: #{e.message}")
    return false, e.message
  end

  private

  def find_or_create_contract
    # On cherche un contrat existant pour ce couple Merch/FVE
    existing = Contract.find_by(merch_id: @merch.id, fve_id: @fve.id)
    return existing if existing.present?

    # Détection des taux IFM/CP (10% si contrat précaire)
    # On se base sur le contract_type de l'offre
    is_precarious = %w[cdd cidd interim].include?(@offer.contract_type.downcase)
    rate = is_precarious ? 0.1 : 0.0

    # Création du contrat
    Contract.create!(
      user: @merch,       # Le propriétaire du contrat (c'est le Merch)
      merch_id: @merch.id, # Redondance explicite dans ta DB
      fve_id: @fve.id,     # Le manager FVE

      # Récupération du code agence depuis le profil du FVE
      agency: @fve.respond_to?(:agency) ? @fve.agency : 'other',

      name: "Contrat #{@offer.mission_type} - #{@offer.company_name}",
      contract_type: @offer.contract_type,

      # Financier
      night_rate: @offer.night_rate,
      ifm_rate: rate,
      cp_rate: rate,

      # Kilométrique
      km_rate: @offer.km_rate || 0.25,
      km_limit: @offer.km_unlimited ? 0 : @offer.km_limit,
      km_unlimited: @offer.km_unlimited
    )
  end

  def create_work_sessions_loop(contract)
    start_date = @offer.start_date.to_date
    end_date   = @offer.end_date.to_date

    # Heures de référence
    ref_start = @offer.start_date
    ref_end   = @offer.end_date

    (start_date..end_date).each do |current_date|
      # Reconstruction des heures pour la date courante
      daily_start = Time.zone.parse("#{current_date} #{ref_start.strftime('%H:%M:%S')}")
      daily_end   = Time.zone.parse("#{current_date} #{ref_end.strftime('%H:%M:%S')}")

      # Gestion Pause
      daily_break_start = nil
      daily_break_end   = nil
      if @offer.break_start_time.present? && @offer.break_end_time.present?
         daily_break_start = Time.zone.parse("#{current_date} #{@offer.break_start_time.strftime('%H:%M:%S')}")
         daily_break_end   = Time.zone.parse("#{current_date} #{@offer.break_end_time.strftime('%H:%M:%S')}")
      end

      # Gestion des débordements (Nuit) si fin < début
      daily_end += 1.day if daily_end < daily_start
      daily_break_end += 1.day if daily_break_start && daily_break_end < daily_break_start

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

        # Construction de l'adresse complète
        store_full_address: [@offer.address, @offer.zipcode, @offer.city].compact.join(', '),

        status: 'accepted'
      )
    end
  end
end
