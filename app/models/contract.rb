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

  # --- 1. Logique Pure : Calcul des KM effectifs ---
  def compute_km(kilometers, recommended: false)
    dist = kilometers.to_f

    # Règle 1 : Si recommandé ou illimité, on paie tout
    return dist if recommended || km_unlimited

    # Règle 2 : Si pas de limite définie (0 ou nil), on paie tout
    return dist if km_limit.nil? || km_limit.zero?

    # Règle 3 : Sinon, on plafonne
    [dist, km_limit.to_f].min
  end

  # --- 2. Calcul Financier : Paiement KM ---
  def km_payment(kilometers, recommended: false)
    return 0.0 unless km_rate.present?

    dist_effective = compute_km(kilometers, recommended: recommended)
    (dist_effective * km_rate.to_f).round(2)
  end

  # --- IFM ---
  def ifm(brut_salary)
    rate = (ifm_rate.presence || 0).to_d
    # Division par 100 car le taux est stocké en pourcentage (ex: 10.0)
    (brut_salary * (rate / 100.0)).round(2)
  end

  # --- CP ---
  def cp(brut_salary)
    base = brut_salary
    rate = (cp_rate.presence || 0).to_d
    # Division par 100 car le taux est stocké en pourcentage (ex: 10.0)
    (base * (rate / 100.0)).round(2)
  end

  # --- TOTAL IFM + CP ---
  def ifm_cp_total(brut_salary)
    ifm(brut_salary) + cp(brut_salary)
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
      # Récupère la valeur brute avant que Rails ne la transforme
      raw_value = read_attribute_before_type_cast(field)

      # Ne touche que si c'est une string contenant une virgule
      next unless raw_value.is_a?(String) && raw_value.include?(',')

      # Remplace et réassigne pour que Rails le prenne en compte
      self[field] = raw_value.tr(',', '.')
    end
  end
end
