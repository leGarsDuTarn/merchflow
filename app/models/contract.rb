# app/models/contract.rb
class Contract < ApplicationRecord
  # ============================================================
  # RELATIONS
  # ============================================================
  belongs_to :user
  belongs_to :fve, class_name: 'User', optional: true
  belongs_to :merch, class_name: 'User', optional: true

  has_many :work_sessions, dependent: :destroy
  has_many :declarations, dependent: :destroy

  # ============================================================
  # ENUM & CONSTANTES
  # ============================================================
  enum :contract_type, {
    cdd: "cdd",
    cidd: "cidd",
    interim: "interim"
  }

  CONTRACT_TYPE_LABELS = {
    "cdd" => "CDD",
    "cidd" => "CIDD",
    "interim" => "Intérim"
  }.freeze

  # ============================================================
  # VALIDATIONS
  # ============================================================
  validates :agency, presence: { message: 'Vous devez sélectionner une agence' }
  validate :agency_must_exist_in_db

  validates :night_rate, :ifm_rate, :cp_rate, numericality: { greater_than_or_equal_to: 0 }
  validates :km_rate, presence: true, numericality: true
  validates :km_limit, numericality: { greater_than_or_equal_to: 0 }

  # ============================================================
  # CALLBACKS
  # ============================================================
  before_validation :normalize_decimal_fields

  # ============================================================
  # CALCULS FINANCIERS
  # ============================================================

  # --- Frais kilométriques ---
  def km_payment(kilometers, recommended: false)
    rate = km_rate.to_f

    effective_km =
      if recommended
        kilometers
      elsif km_limit.positive?
        [kilometers, km_limit.to_f].min
      else
        kilometers
      end

    (effective_km * rate).round(2)
  end

  # --- IFM (taux dynamique via ifm_rate) ---
  def ifm(brut_salary)
    rate = (ifm_rate.presence || 0).to_d
    (brut_salary * rate).round(2)
  end

  # --- CP (calculé sur brut + IFM, taux dynamique via cp_rate) ---
  def cp(brut_salary)
    base = brut_salary
    rate = (cp_rate.presence || 0).to_d
    (base * rate).round(2)
  end

  # ============================================================
  # HELPERS
  # ============================================================
  def self.agency_options
    Agency.where.not(code: 'other').order(:label).pluck(:label, :code)
  end

  def agency_label
    Agency.find_by(code: agency)&.label || agency.to_s.humanize
  end

  def contract_type_label
    CONTRACT_TYPE_LABELS[contract_type] || contract_type.to_s.humanize
  end

  # ============================================================
  # PRIVÉ
  # ============================================================
  private

  def agency_must_exist_in_db
    return if agency.blank?

    errors.add(:agency, "n'est pas une agence valide") unless Agency.exists?(code: agency)
  end

  def normalize_decimal_fields
    %i[km_rate night_rate ifm_rate cp_rate].each do |field|
      value = self[field]
      next if value.blank?

      self[field] = value.to_s.tr(',', '.')
    end
  end
end
