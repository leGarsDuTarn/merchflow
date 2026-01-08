class RecruitMerchService
  attr_reader :error_message

  def initialize(job_application)
    @application = job_application
    @offer       = job_application.job_offer
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

      # 3. Création des sessions de travail (Version Flexible)
      create_work_sessions_loop(contract)

      # 4. Validation finale de la candidature
      @application.update!(status: 'accepted')
    end

    true
  rescue ActiveRecord::RecordInvalid => e
    @error_message = "Erreur de validation : #{e.record.errors.full_messages.join(', ')}"
    false
  rescue StandardError => e
    @error_message = "Une erreur inattendue est survenue : #{e.message}"
    false
  end

  private

  def find_or_create_contract
    existing = Contract.find_by(merch_id: @merch.id, fve_id: @fve.id)
    return existing if existing.present?

    # A. Gestion de l'Agence
    agency_code = @fve.respond_to?(:agency) ? @fve.agency : nil
    unless Agency.exists?(code: agency_code)
      raise StandardError, "Le profil du FVE n'a pas d'agence valide associée."
    end

    # B. Type de contrat
    c_type = @offer.contract_type.to_s.downcase
    c_type = 'cdd' unless Contract.contract_types.keys.include?(c_type)

    # C. Calcul des taux (Harmonisation format 10.0 pour 10%)
    is_precarious = %w[cdd cidd interim].include?(c_type)
    standard_rate = is_precarious ? 10.0 : 0.0

    Contract.create!(
      name: "Mission #{@offer.mission_type.capitalize} - #{@offer.company_name}",
      user: @merch,
      merch: @merch,
      fve: @fve,
      agency: agency_code,
      contract_type: c_type,

      # --- GESTION NUIT DYNAMIQUE ---
      night_rate: @offer.night_rate || 50.0, # Transfère le taux (ex: 50.0)
      night_start: @offer.night_start,       # Transfère l'heure de début (ex: 21)
      night_end: @offer.night_end,           # Transfère l'heure de fin (ex: 6)
      # ------------------------------

      ifm_rate: standard_rate,
      cp_rate: standard_rate,
      km_rate: @offer.km_rate || 0.29,
      km_limit: @offer.km_unlimited ? 0 : (@offer.km_limit || 0),
      km_unlimited: @offer.km_unlimited || false
    )
  end

  def create_work_sessions_loop(contract)
    @offer.job_offer_slots.each do |slot|

      # 1. Construction des timestamps précis avec TimeZone (Paris)
      daily_start = Time.zone.parse("#{slot.date} #{slot.start_time.strftime('%H:%M')}")
      daily_end   = Time.zone.parse("#{slot.date} #{slot.end_time.strftime('%H:%M')}")

      # 2. Gestion de la Nuit (Si fin < début, c'est le lendemain)
      daily_end += 1.day if daily_end <= daily_start

      # 3. Gestion des Pauses
      daily_break_start, daily_break_end = nil, nil

      if slot.break_start_time.present? && slot.break_end_time.present?
        daily_break_start = Time.zone.parse("#{slot.date} #{slot.break_start_time.strftime('%H:%M')}")
        daily_break_end   = Time.zone.parse("#{slot.date} #{slot.break_end_time.strftime('%H:%M')}")

        # Cas rare : pause qui traverse minuit
        daily_break_end += 1.day if daily_break_end < daily_break_start
      end

      # 4. Création de la session
      WorkSession.create!(
        contract: contract,
        date: slot.date,
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
