class RecruitMerchService
  attr_reader :error_message

  def initialize(job_application)
    @application = job_application
    @offer       = job_application.job_offer
    @merch       = job_application.merch
    @fve         = @offer.fve
  end

  def call
    if @application.status == 'accepted'
      @error_message = "Ce candidat a déjà été recruté pour cette mission."
      return false
    end

    ActiveRecord::Base.transaction do
      contract = find_or_create_contract
      create_work_sessions_loop(contract)

      # Valide le candidat actuel
      @application.update!(status: 'accepted')

      # Refuse automatiquement les autres si l'offre est complète
      reject_others_if_full!
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
    agency_code = @fve.respond_to?(:agency) ? @fve.agency : nil
    
    # Un merch (user) peut avoir plusieurs contrats (1 par agence)
    existing = Contract.find_by(
      user_id: @merch.id,
      agency: agency_code
    )

    if existing.present?
      return existing
    end

    # Validation de l'agence avant création
    unless Agency.exists?(code: agency_code)
      raise StandardError, "Le profil du FVE n'a pas d'agence valide associée (agency: #{agency_code.inspect})"
    end

    # Type de contrat
    c_type = @offer.contract_type.to_s.downcase
    c_type = 'cdd' unless Contract.contract_types.keys.include?(c_type)

    # Calcul des taux
    is_precarious = %w[cdd cidd interim].include?(c_type)
    standard_rate = is_precarious ? 10.0 : 0.0

    Contract.create!(
      name: "Mission #{@offer.mission_type.capitalize} - #{@offer.company_name}",

      # user_id est la clé principale
      user: @merch,          # belongs_to :user
      fve_id: @fve.id,       # Pour traçabilité
      merch_id: @merch.id,   # Pour traçabilité (si besoin)

      agency: agency_code,
      contract_type: c_type,
      night_rate: @offer.night_rate || 50.0,
      night_start: @offer.night_start,
      night_end: @offer.night_end,
      ifm_rate: standard_rate,
      cp_rate: standard_rate,
      km_rate: @offer.km_rate || 0.29,
      km_limit: @offer.km_unlimited ? 0 : (@offer.km_limit || 0),
      km_unlimited: @offer.km_unlimited || false
    )
  end

  def create_work_sessions_loop(contract)
    @offer.job_offer_slots.each do |slot|
      daily_start = Time.zone.parse("#{slot.date} #{slot.start_time.strftime('%H:%M')}")
      daily_end   = Time.zone.parse("#{slot.date} #{slot.end_time.strftime('%H:%M')}")
      daily_end += 1.day if daily_end <= daily_start

      daily_break_start, daily_break_end = nil, nil
      if slot.break_start_time.present? && slot.break_end_time.present?
        daily_break_start = Time.zone.parse("#{slot.date} #{slot.break_start_time.strftime('%H:%M')}")
        daily_break_end   = Time.zone.parse("#{slot.date} #{slot.break_end_time.strftime('%H:%M')}")
        daily_break_end += 1.day if daily_break_end < daily_break_start
      end

      WorkSession.find_or_create_by!(
        contract: contract,
        job_offer: @offer,
        date: slot.date,
        start_time: daily_start,
        end_time: daily_end
      ) do |ws|
        ws.break_start_time = daily_break_start
        ws.break_end_time   = daily_break_end
        ws.hourly_rate      = @offer.hourly_rate
        ws.company          = @offer.company_name
        ws.store            = @offer.store_name
        ws.store_full_address = [@offer.address, @offer.zipcode, @offer.city].compact.join(', ')
        ws.status           = 'accepted'
      end
    end
  end

  def reject_others_if_full!
    # Recharge l'offre pour avoir le compte à jour
    if @offer.reload.remaining_spots <= 0
      # Prend tous les autres candidats en attente sur cette offre
      # et les passe à 'rejected'.
      @offer.job_applications
            .where(status: 'pending')
            .where.not(id: @application.id) # Sécurité pour ne pas toucher celui qu'on traite
            .update_all(status: 'rejected')
    end
  end
end
