class Contract < ApplicationRecord
  # ============================================================
  # 1. RELATIONS
  # ============================================================
  belongs_to :user
  belongs_to :fve, class_name: 'User', optional: true
  belongs_to :merch, class_name: 'User', optional: true

  has_many :work_sessions, dependent: :destroy
  has_many :declarations, dependent: :destroy

  # ============================================================
  # 2. ENUM & CONSTANTES
  # ============================================================
  enum :contract_type, { cdd: "cdd", cidd: "cidd", interim: "interim" }

  CONTRACT_TYPE_LABELS = {
    "cdd" => "CDD",
    "cidd" => "CIDD",
    "interim" => "Intérim"
  }.freeze

  # ============================================================
  # 3. BLINDAGE & VALIDATIONS (LA SÉCURITÉ)
  # ============================================================

  # Nettoyage avant toute validation (transforme "10,5" en "10.5")
  before_validation :normalize_decimal_fields

  validates :agency, presence: { message: 'Vous devez sélectionner une agence' }
  validate :agency_must_exist_in_db

  # SÉCURITÉ 1 : Limites logiques
  # Empêche de mettre un taux négatif OU un taux absurde (ex: > 50% pour IFM c'est louche)
  # Empêche aussi de mettre "100" si l'user pense que c'est 100%
  validates :ifm_rate, :cp_rate, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 50, # Garde-fou : Personne n'a 50% de CP
    allow_nil: true
  }

  validates :night_rate, numericality: { greater_than_or_equal_to: 0, allow_nil: true }

  # KM Rate est obligatoire pour les calculs, sinon ça crash ou fait 0
  validates :km_rate, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :km_limit, numericality: { greater_than_or_equal_to: 0, allow_nil: true }

  # ============================================================
  # 4. CALCULS FINANCIERS (PRÉCISION)
  # ============================================================

  # --- Calcul des KM effectifs ---
  def compute_km(kilometers, recommended: false)
    dist = BigDecimal(kilometers.to_s)

    return dist if recommended || km_unlimited
    return dist if km_limit.nil? || km_limit.zero?

    [dist, BigDecimal(km_limit.to_s)].min
  end

  # --- Paiement KM ---
  def km_payment(kilometers, recommended: false)
    return 0.0 unless km_rate.present?

    dist_effective = compute_km(kilometers, recommended: recommended)
    rate = BigDecimal(km_rate.to_s)

    (dist_effective * rate).round(2)
  end

  # --- IFM (Base 100) ---
  def ifm(brut_salary)
    base = BigDecimal(brut_salary.to_s)
    rate = BigDecimal(ifm_rate.to_s)

    # Formule : Salaire * (Taux / 100)
    (base * (rate / 100.0)).round(2)
  end

  # --- CP (Base 100) ---
  def cp(brut_salary)
    base = BigDecimal(brut_salary.to_s)
    rate = BigDecimal(cp_rate.to_s)

    (base * (rate / 100.0)).round(2)
  end

  # --- TOTAL ---
  def ifm_cp_total(brut_salary)
    ifm(brut_salary) + cp(brut_salary)
  end

  # ============================================================
  # 5. HELPERS D'AFFICHAGE
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
  # 6. PRIVÉ (MÉCANIQUE INTERNE)
  # ============================================================
  private

  def agency_must_exist_in_db
    return if agency.blank?
    errors.add(:agency, "n'est pas une agence valide") unless Agency.exists?(code: agency)
  end

  # Gère le cas où l'utilisateur tape "10,5" ou copie-colle un nombre non conforme
  def normalize_decimal_fields
    fields = %i[km_rate night_rate ifm_rate cp_rate km_limit]

    fields.each do |field|
      raw_value = read_attribute_before_type_cast(field)

      next if raw_value.nil?

      if raw_value.is_a?(String)
        # Remplace virgule par point
        clean_value = raw_value.tr(',', '.')
        # Supprime les espaces insécables ou autres saletés
        clean_value = clean_value.gsub(/\s+/, '')
        self[field] = clean_value
      end
    end
  end
end
