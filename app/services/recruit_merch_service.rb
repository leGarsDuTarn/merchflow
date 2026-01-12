class RecruitMerchService
  attr_reader :error_message

  def initialize(job_application)
    @application = job_application
    @offer       = job_application.job_offer
    @merch       = job_application.merch
    @fve         = @offer.fve
  end

  def call
    # Vérifications en amont avant toute modification
    return false unless validate_application_status
    return false unless validate_schedule_conflicts
    return false unless validate_availability

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

  def validate_application_status
    if @application.status == 'accepted'
      @error_message = "Ce candidat a déjà été recruté."
      return false
    end
    true
  end

  def validate_schedule_conflicts
    @offer.job_offer_slots.each do |slot|
      # Récupérer toutes les sessions de travail du merch à cette date
      conflicting_sessions = @merch.work_sessions
                                   .where(date: slot.date)
                                   .where.not(status: [:cancelled, :rejected])

      conflicting_sessions.each do |session|
        if times_overlap?(slot.start_time, slot.end_time, session.start_time, session.end_time)
          @error_message = "Le merch est déjà en mission le #{slot.date} (#{slot.start_time.strftime('%H:%M')}-#{slot.end_time.strftime('%H:%M')})"
          return false
        end
      end
    end
    true
  end

  def validate_availability
    @offer.job_offer_slots.each do |slot|
      # Vérifier si le merch a posé une indisponibilité ce jour-là
      if @merch.unavailabilities.exists?(date: slot.date)
        @error_message = "Le merch a posé une indisponibilité le #{slot.date}"
        return false
      end
    end
    true
  end

  def times_overlap?(start1, end1, start2, end2)
    # Convertir en Time si nécessaire pour comparaison
    s1 = ensure_time(start1)
    e1 = ensure_time(end1)
    s2 = ensure_time(start2)
    e2 = ensure_time(end2)

    # Deux créneaux se chevauchent si l'un commence avant que l'autre ne finisse
    s1 < e2 && s2 < e1
  end

  def ensure_time(time_value)
    return time_value if time_value.is_a?(Time)
    Time.zone.parse(time_value.to_s)
  end

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
