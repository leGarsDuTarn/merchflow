# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    # Redirection selon le rôle
    if current_user.admin?
      redirect_to admin_dashboard_path and return
    elsif current_user.fve?
      redirect_to fve_dashboard_path and return
    end

    # ==========================================================
    # 1. GESTION DE LA DATE (Sécurisée)
    # ==========================================================
    @year = (params[:year] || Date.current.year).to_i
    @month = (params[:month] || Date.current.month).to_i

    begin
      @target_date = Date.new(@year, @month, 1)
    rescue ArgumentError
      @target_date = Date.current.beginning_of_month
      @year = @target_date.year
      @month = @target_date.month
    end

    @is_current_month = (@target_date.beginning_of_month == Date.current.beginning_of_month)
    @user = current_user

    # Navigation
    @prev_month = (@target_date - 1.month).month
    @prev_year  = (@target_date - 1.month).year
    @next_month = (@target_date + 1.month).month
    @next_year  = (@target_date + 1.month).year

    # ==========================================================
    # 2. CHARGEMENT DES DONNÉES (Optimisation N+1)
    # ==========================================================

    # .includes(:contract) est CRUCIAL ici.
    # Il permet de charger les contrats en même temps que les missions.
    # Sinon, la boucle "par agence" ferait une requête SQL par mission.
    @monthly_sessions = @user.work_sessions
                             .includes(:contract)
                             .for_month(@year, @month)

    # ==========================================================
    # 3. CALCULS FINANCIERS (En mémoire = Plus rapide)
    # ==========================================================

    # Au lieu de rappeler la BDD, on somme ce qu'on a déjà chargé dans @monthly_sessions

    # HEURES
    @total_hours_month = @monthly_sessions.sum { |ws| ws.duration_minutes.to_f / 60 }

    # BRUT (Salaire + IFM + CP)
    # Note : On somme les composants un par un pour être précis au centime
    @total_brut_month = @monthly_sessions.sum { |ws| ws.brut + ws.amount_ifm + ws.amount_cp }

    # FRAIS ANNEXES
    @total_fees_month = @monthly_sessions.sum(&:total_fees)

    # NET TOTAL ESTIMÉ
    # On utilise la méthode du modèle WorkSession qui contient toute la logique (frais inclus)
    @net_total_estimated_month = @monthly_sessions.sum(&:net_total)

    # KM
    @km_month         = @monthly_sessions.sum(&:effective_km)
    @km_payment_month = @monthly_sessions.sum(&:km_payment_final)

    # ==========================================================
    # 4. DONNÉES PAR AGENCE (Tableau détaillé)
    # ==========================================================

    @by_agency = @monthly_sessions.group_by { |ws| ws.contract.agency_label }.map do |agency, sessions|
      # Calculs intermédiaires pour cette agence
      # On utilise 0.78 comme approximation du net fiscal sur le brut total
      net_salary = sessions.sum { |s| (s.brut + s.amount_ifm + s.amount_cp) * 0.78 }
      km_pay     = sessions.sum(&:km_payment_final)
      fees       = sessions.sum(&:total_fees)

      {
        agency: agency,
        hours: sessions.sum { |s| s.duration_minutes.to_f / 60 },
        brut: sessions.sum { |s| s.brut + s.amount_ifm + s.amount_cp },
        km: sessions.sum(&:effective_km),
        km_payment: km_pay,
        fees: fees,
        net_salary: net_salary,
        # Total virement Agence = Salaire Net + KM + Frais
        total_transfer: (net_salary + km_pay + fees).round(2)
      }
    end || []

    # ==========================================================
    # 5. NOTIFICATIONS
    # ==========================================================
    @pending_proposals_count = @user.received_mission_proposals.where(status: :pending).count

    @show_visibility_alert = false
    if @user.merch?
      # On utilise build pour ne pas créer d'enregistrement vide en base si l'utilisateur visite juste le dashboard
      settings = @user.merch_setting || @user.build_merch_setting
      if !settings.share_planning || !settings.allow_identity
        @show_visibility_alert = true
      end
    end
  end
end
