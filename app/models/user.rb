class User < ApplicationRecord
  # ============================================================
  # DEVISE MODULES
  # ============================================================

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # ============================================================
  # RELATIONS
  # ============================================================

  has_many :contracts, dependent: :destroy
  has_many :work_sessions, through: :contracts
  has_many :declarations, dependent: :destroy

  # ============================================================
  # VALIDATIONS
  # ============================================================

  validates :address, presence: true, allow_blank: true
  validates :zipcode, presence: true, allow_blank: true
  validates :city, presence: true, allow_blank: true

  # ============================================================
  # MÉTHODES UTILITAIRES ADRESSE
  # ============================================================

  # Adresse complète formatée (pour Google API)
  def full_address
    [address, zipcode, city].compact.join(", ")
  end

  # Vérifie que l'adresse est complète pour calcul distances
  def address_complete?
    address.present? && zipcode.present? && city.present?
  end

  # ============================================================
  # MÉTHODES DASHBOARD
  # ============================================================

  # Total des minutes travaillées (toutes missions)
  def total_minutes_worked
    work_sessions.sum(:duration_minutes)
  end

  def total_hours_worked
    (total_minutes_worked / 60.0).round(2)
  end

  # Total brut toutes missions
  def total_brut
    work_sessions.inject(0) { |sum, ws| sum + ws.brut }
  end

  # Total IFM + CP
  def total_ifm_cp
    work_sessions.inject(0) { |sum, ws| sum + ws.contract.ifm_cp_total(ws.brut) }
  end

  # Total kilomètres
  def total_km
    work_sessions.inject(0) { |sum, ws| sum + ws.effective_km.to_f }
  end

  # Total remboursement km
  def total_km_payment
    work_sessions.inject(0) do |sum, ws|
      sum + ws.contract.km_payment(ws.effective_km.to_f, recommended: ws.recommended)
    end
  end

  # ============================================================
  # MÉTHODES PAR EMPLOYEUR
  # ============================================================

  def total_by_agency
    contracts.includes(:work_sessions).map do |contract|
      {
        agency: contract.agency_label,
        brut: contract.work_sessions.sum(&:brut),
        hours: (contract.work_sessions.sum(:duration_minutes) / 60.0).round(2),
        km: contract.work_sessions.sum(&:effective_km)
      }
    end
  end
end
