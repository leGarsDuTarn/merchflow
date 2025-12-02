class Contract < ApplicationRecord
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

  enum :agency, {
    actiale: "actiale",
    rma: "rma",
    edelvi: "edelvi",
    mdf: "dmf",
    cpm: "cpm",
    idtt: "idtt",
    sarawak: "sarawak",
    optimark: "optimark",
    strada: "strada",
    andeol: "andeol",
    demosthene: "demosthene",
    altavia: "altavia",
    marcopolo: "marcopolo",
    virageconseil: "virageconseil",
    upsell: "upsell",
    idal: "idal",
    armada: "armada",
    sellbytel: "sellbytel"
  }

  AGENCY_LABELS = {
    "actiale" => "Actiale",
    "rma" => "RMA SA",
    "edelvi" => "Edelvi",
    "mdf" => "DMF",
    "cpm" => "CPM",
    "idtt" => "Idtt Interim Distribution",
    "sarawak" => "Sarawak",
    "optimark" => "Optimark",
    "strada" => "Strada Marketing",
    "andeol" => "Andéol",
    "demosthene" => "Démosthène",
    "altavia" => "Altavia Fil Conseil",
    "marcopolo" => "MarcoPolo Performance",
    "virageconseil" => "Virage Conseil",
    "upsell" => "Upsell",
    "idal" => "iDal",
    "armada" => "Armada",
    "sellbytel" => "Sellbytel"
  }.freeze

  def agency_label
    return "Agence inconnue" if agency.blank?

    AGENCY_LABELS[agency] || agency.to_s.humanize
  end


  def self.agency_options
    agencies.keys.map { |key| [AGENCY_LABELS[key], key] }
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

  def normalize_decimal_fields
    %i[km_custom hourly_rate].each do |field|
      value = self[field]
      next if value.blank?

      self[field] = value.to_s.tr(',', '.')
    end
  end
end
