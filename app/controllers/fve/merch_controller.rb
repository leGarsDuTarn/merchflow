# app/controllers/fve/merch_controller.rb
class Fve::MerchController < ApplicationController
  before_action :authenticate_user!
  before_action :require_fve!

  def index
    authorize %i[fve merch]

    # Base : tous les merch avec eager loading pour optimisation
    @merch = User.merch.includes(:contracts, :work_sessions, :unavailabilities)

    # FILTRE : Ville
    if params[:city].present?
      @merch = @merch.where("LOWER(city) LIKE ?", "%#{params[:city].downcase}%")
    end

    # FILTRE : Code postal exact ou début
    if params[:zipcode].present?
      @merch = @merch.where("zipcode LIKE ?", "#{params[:zipcode]}%")
    end

    # FILTRE : Département (2 premiers chiffres du code postal)
    if params[:department].present?
      @merch = @merch.where("zipcode LIKE ?", "#{params[:department]}%")
    end

    # FILTRE : A travaillé pour une entreprise spécifique
    if params[:company].present?
      @merch = @merch.joins(:work_sessions)
                     .where("LOWER(work_sessions.company) LIKE ?", "%#{params[:company].downcase}%")
                     .distinct
    end

    # FILTRE : A déjà un contrat avec ma FVE
    if params[:has_contract_with_me] == "1"
      @merch = @merch.joins(:contracts)
                     .where(contracts: { agency: current_user.agency })
                     .distinct
    end

    # FILTRE : Coordonnées visibles uniquement (premium FVE requis)
    if params[:only_with_contact] == "1" && current_user.premium?
      @merch = @merch.where("allow_email = ? OR allow_phone = ? OR allow_identity = ?",
                            true, true, true)
    end

    # ----------------------------------------------------------------------
    # FILTRE : Disponibilité sur une période
    # Inclut l'indisponibilité personnelle (Unavailability) ET les missions planifiées (WorkSession)
    # ----------------------------------------------------------------------

    if params[:start_date].present? || params[:end_date].present?
      start_date = params[:start_date].present? ? (Date.parse(params[:start_date]) rescue nil) : nil
      end_date   = params[:end_date].present? ? (Date.parse(params[:end_date]) rescue nil) : nil

      # On définit la condition SQL pour les dates
      date_condition_sql = nil

      if start_date && end_date
        date_condition_sql = "date BETWEEN '#{start_date}' AND '#{end_date}'"
        work_session_condition = "DATE(work_sessions.start_time) BETWEEN '#{start_date}' AND '#{end_date}'"
      elsif start_date
        date_condition_sql = "date >= '#{start_date}'"
        work_session_condition = "DATE(work_sessions.start_time) >= '#{start_date}'"
      elsif end_date
        date_condition_sql = "date <= '#{end_date}'"
        work_session_condition = "DATE(work_sessions.start_time) <= '#{end_date}'"
      end

      if date_condition_sql.present?

        # 1. IDs indisponibles par Indisponibilité personnelle
        unavailable_by_unavailability_ids = Unavailability
          .where(date_condition_sql)
          .pluck(:user_id)
          .uniq

        # 2. IDs indisponibles par Missions planifiées (WorkSession)
        unavailable_by_work_session_ids = User.joins(contracts: :work_sessions)
          .where(work_session_condition)
          .pluck(:id)
          .uniq

        # Combinaison des IDs non-disponibles (Union d'ensembles)
        unavailable_user_ids = unavailable_by_unavailability_ids | unavailable_by_work_session_ids

        # Exclusion des marchands occupés
        @merch = @merch.where.not(id: unavailable_user_ids)
      end
    end

    # TRI par ville puis nom
    @merch = @merch.order(:city, :lastname, :firstname)
  end

  def show
    @merch_user = User.merch.find(params[:id])
    authorize [:fve, @merch_user]

    # ========== CONFIDENTIALITÉ : DONNÉES AFFICHABLES ==========
    @name  = @merch_user.displayable_name(current_user)
    @email = @merch_user.displayable_email(current_user)
    @phone = @merch_user.displayable_phone(current_user)

    # ========== INFOS DÉTAILLÉES POUR LA VUE SHOW ==========
    @contracts_with_my_agency = @merch_user.contracts.where(agency: current_user.agency)
    @work_sessions = @merch_user.work_sessions.includes(:contract).order(date: :desc).limit(20)
    @companies_worked_with = @merch_user.work_sessions.pluck(:company).compact.uniq.sort
    @unavailabilities = @merch_user.unavailabilities.where("date >= ?", Date.today).order(:date)

    # Stats
    @total_hours = @merch_user.total_hours_worked
    @total_missions = @merch_user.work_sessions.count
  end

  private

  def require_fve!
    unless current_user&.fve?
      redirect_to root_path, alert: 'Accès réservé aux forces de vente.'
    end
  end
end
