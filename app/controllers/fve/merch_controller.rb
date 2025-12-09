module Fve
  class MerchController < ApplicationController
    before_action :authenticate_user!
    before_action :require_fve!

    def index
      authorize %i[fve merch]

      # 1. BASE : On prend tous les merchs actifs
      @merch = User.merch.includes(:contracts, :work_sessions, :unavailabilities, :merch_setting)

      # =================================================================
      # FILTRE 1 : DISPONIBILITÉ PRÉCISE (Date + Heure Début + Heure Fin)
      # Ce filtre a la PRIORITÉ sur le filtre large
      # =================================================================
      if params[:target_date].present? && params[:start_time].present? && params[:end_time].present?

        target_date = Date.parse(params[:target_date]) rescue nil
        req_start_time = Time.parse(params[:start_time]) rescue nil
        req_end_time = Time.parse(params[:end_time]) rescue nil

        if target_date && req_start_time && req_end_time
          # A. IDENTIFIER CEUX QUI ONT POSÉ UNE INDISPONIBILITÉ (Journée entière)
          unavailable_ids_day = Unavailability.where(date: target_date).pluck(:user_id)

          # B. IDENTIFIER CEUX QUI SONT EN MISSION (Chevauchement temporel)
          # On compare uniquement les HEURES car start_time/end_time contiennent des dates incorrectes
          # Formule de chevauchement : session_start_hour < req_end_hour AND session_end_hour > req_start_hour
          busy_contract_ids = WorkSession
            .where(date: target_date)
            .where(
              "EXTRACT(HOUR FROM start_time) * 60 + EXTRACT(MINUTE FROM start_time) < ? AND EXTRACT(HOUR FROM end_time) * 60 + EXTRACT(MINUTE FROM end_time) > ?",
              req_end_time.hour * 60 + req_end_time.min,
              req_start_time.hour * 60 + req_start_time.min
            )
            .pluck(:contract_id)

          # Récupérer les IDs des Users via leurs Contrats
          busy_user_ids = Contract.where(id: busy_contract_ids).pluck(:user_id)

          # C. EXCLUSION : Retirer les IDs de ceux qui sont occupés ou indisponibles
          ids_to_exclude = (unavailable_ids_day + busy_user_ids).uniq

          Rails.logger.debug "=== DEBUG DISPONIBILITÉ PRÉCISE ==="
          Rails.logger.debug "Date: #{target_date}"
          Rails.logger.debug "Créneau demandé: #{req_start_time.strftime('%H:%M')} - #{req_end_time.strftime('%H:%M')}"
          Rails.logger.debug "IDs indisponibles (unavailability): #{unavailable_ids_day}"
          Rails.logger.debug "Contract IDs occupés: #{busy_contract_ids}"
          Rails.logger.debug "User IDs occupés: #{busy_user_ids}"
          Rails.logger.debug "Total exclusions: #{ids_to_exclude}"

          @merch = @merch.where.not(id: ids_to_exclude)
        end

      # =================================================================
      # FILTRE 1-BIS : DISPONIBILITÉ LARGE (Période Date à Date)
      # Ne s'applique QUE si le filtre précis n'est pas utilisé
      # =================================================================
      elsif params[:start_date].present? || params[:end_date].present?
        start_date = params[:start_date].present? ? (Date.parse(params[:start_date]) rescue nil) : nil
        end_date   = params[:end_date].present? ? (Date.parse(params[:end_date]) rescue nil) : nil

        if start_date || end_date
          date_condition_sql = []
          date_condition_sql << "date >= '#{start_date}'" if start_date
          date_condition_sql << "date <= '#{end_date}'" if end_date
          date_condition_str = date_condition_sql.join(' AND ')

          # 1. IDs indisponibles par Indisponibilité personnelle
          unavailable_ids = Unavailability.where(date_condition_str).pluck(:user_id)

          # 2. IDs indisponibles par Missions planifiées (WorkSession)
          busy_contract_ids = WorkSession.where(date_condition_str).pluck(:contract_id)
          busy_user_ids = Contract.where(id: busy_contract_ids).pluck(:user_id)

          # Exclusion des marchands occupés
          @merch = @merch.where.not(id: (unavailable_ids | busy_user_ids).uniq)
        end
      end

      # =================================================================
      # FILTRES CLASSIQUES
      # =================================================================

      if params[:query].present?
        search_term = "%#{params[:query].strip.downcase}%"
        full_name_condition = "LOWER(CONCAT(firstname, ' ', lastname)) LIKE :search"
        @merch = @merch.where("LOWER(firstname) LIKE :search OR LOWER(lastname) LIKE :search OR LOWER(username) LIKE :search OR #{full_name_condition}", search: search_term)
      end

      if params[:city].present?
        @merch = @merch.where("LOWER(city) LIKE ?", "%#{params[:city].downcase}%")
      end

      if params[:zipcode].present?
        @merch = @merch.where("zipcode LIKE ?", "#{params[:zipcode]}%")
      end

      if params[:department].present?
        @merch = @merch.where("zipcode LIKE ?", "#{params[:department]}%")
      end

      # FILTRE : Favoris uniquement
      if params[:only_favorites] == "1"
        # On filtre pour ne garder que ceux qui sont dans les favoris du current_user
        @merch = @merch.where(id: current_user.favorite_merchs.select(:id))
      end

      if params[:company].present?
        @merch = @merch.joins(contracts: :work_sessions)
                       .where("LOWER(work_sessions.company) LIKE ?", "%#{params[:company].downcase}%")
                       .distinct
      end

      if params[:has_contract_with_me] == "1"
        @merch = @merch.joins(:contracts)
                       .where(contracts: { agency: current_user.agency })
                       .distinct
      end

      if params[:only_with_contact] == "1" && current_user.premium?
        contactable_base = User.merch.joins(:merch_setting)
        condition = contactable_base.where(merch_settings: { allow_contact_email: true })
                      .or(contactable_base.where(merch_settings: { allow_contact_phone: true }))
                      .or(contactable_base.where(merch_settings: { allow_identity: true }))
        @merch = @merch.merge(condition).distinct
      end

      if params[:prefers_merch] == "1"
        @merch = @merch.joins(:merch_setting).where(merch_settings: { role_merch: true })
      end

      if params[:prefers_anim] == "1"
        @merch = @merch.joins(:merch_setting).where(merch_settings: { role_anim: true })
      end

      @merch = @merch.order(:city, :lastname, :firstname)
    end

    def show
      @merch_user = User.merch.find(params[:id])
      authorize [:fve, @merch_user]

      @merch_user.create_merch_setting! unless @merch_user.merch_setting.present?

      @name  = @merch_user.displayable_name(current_user)
      @email = @merch_user.displayable_email(current_user)
      @phone = @merch_user.displayable_phone(current_user)

      @contracts_with_my_agency = @merch_user.contracts.where(agency: current_user.agency)
      @work_sessions = @merch_user.work_sessions.includes(:contract).order(date: :desc).limit(20)
      @companies_worked_with = @merch_user.work_sessions.pluck(:company).compact.uniq.sort
      @unavailabilities = @merch_user.unavailabilities.where("date >= ?", Date.today).order(:date)

      @total_hours = @merch_user.total_hours_worked
      @total_missions = @merch_user.work_sessions.count
    end

    def favorites
      @merch = current_user.favorite_merchs.includes(:merch_setting)
    end

    private

    def require_fve!
      unless current_user&.fve?
        redirect_to root_path, alert: 'Accès réservé aux forces de vente.'
      end
    end
  end
end
