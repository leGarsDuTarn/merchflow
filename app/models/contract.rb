class Contract < ApplicationRecord
  # Importe les constantes et la méthode d'affichage d'agence
  include AgencyConstants

  belongs_to :user
  belongs_to :fve, class_name: 'User', optional: true
  # L'utilisateur Prestataire (Merch)
  # Le contrat est généralement lié à un seul user (user_id), mais si merch_id sert à identifier
  # le prestataire dans le cadre d'une relation complexe (par exemple, si user_id est l'admin)
  # l'association est bien définie.
  belongs_to :merch, class_name: 'User', optional: true
  has_many :work_sessions, dependent: :destroy
  has_many :declarations, dependent: :destroy

  # ============================================================
  # AGENCIES ENUM + LABELS
  # ============================================================

  # Utilise l'énumération définie dans le Concern
  enum :agency, AgencyConstants::AGENCY_ENUMS

  def self.agency_options
    # Utilise la constante AGENCY_LABELS du Concern pour générer les options
    AgencyConstants::AGENCY_ENUMS.keys.map { |key| [AgencyConstants::AGENCY_LABELS[key], key] }
  end

  # ============================================================
  # CONTRACT TYPE ENUM + LABELS
  # ============================================================

  enum :contract_type, {
    cdd: "cdd",
    cidd: "cidd",
    interim: "interim"
  }

  CONTRACT_TYPE_LABELS = {
    "cdd" => "CDD",
    "cidd" => "CIDD",
    "interim" => "Intérim",
    "cdi" => "CDI"
  }.freeze

  def contract_type_label
    CONTRACT_TYPE_LABELS[contract_type] || contract_type.humanize
  end

  # ============================================================
  # VALIDATIONS
  # ============================================================
  validates :agency, presence: { message: 'Vous devez sélectionner une agence' }
  validates :night_rate, :ifm_rate, :cp_rate,
            numericality: { greater_than_or_equal_to: 0 }
  validates :km_rate, presence: true, numericality: true
  validates :km_limit,
            numericality: { greater_than_or_equal_to: 0 }

  # ============================================================
  # CALLBACK
  # ============================================================
  before_validation :normalize_decimal_fields
  # ============================================================
  # MÉTHODES MÉTIER
  # ============================================================

  # Indemnités de fin de mission
  def ifm(brut)
    (brut * ifm_rate).round(2)
  end

  # Congés payés
  def cp(brut)
    (brut * cp_rate).round(2)
  end

  # IFM + CP
  def ifm_cp_total(brut)
    ifm(brut) + cp(brut)
  end

  # Km remboursables selon limite ou recommandé
  def compute_km(distance_km, recommended: false)
    return distance_km if km_unlimited || recommended

    [distance_km, km_limit].min
  end

  # Paiement km
  def km_payment(distance_km, recommended: false)
    km = compute_km(distance_km, recommended: recommended)
    (km * km_rate).round(2)
  end

  # ============================================================
  # PRIVATE
  # ============================================================

  private

  def normalize_decimal_fields
    # NOTE: L'ancienne boucle utilisait %i[km_custom hourly_rate]
    # qui sont des champs de WorkSession, pas Contract.
    # Si ces champs existent vraiment dans Contract, laissez-les.
    # Sinon, seuls les champs spécifiques à Contract (km_rate, night_rate, etc.) devraient être là.

    # En supposant que vous normalisez les taux :
    %i[km_rate night_rate ifm_rate cp_rate].each do |field|
      value = self[field]
      next if value.blank?

      self[field] = value.to_s.tr(',', '.')
    end
  end
end
