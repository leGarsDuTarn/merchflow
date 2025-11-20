class Contract < ApplicationRecord
  belongs_to :user
  has_many :work_sessions, dependent: :destroy
  has_many :declarations, dependent: :destroy

  # ============================================================
  # AGENCIES ENUM + LABELS
  # ============================================================

  enum :agency, {
    actiale: "actiale",
    rma: "rma",
    edelvi: "edelvi",
    mdf: "mdf",
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
    sellbytel: "sellbytel",
    other_agency: "other_agency"
  }

  AGENCY_LABELS = {
    "actiale" => "Actiale",
    "rma" => "RMA SA",
    "edelvi" => "Edelvi",
    "mdf" => "MDF",
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
    "sellbytel" => "Sellbytel",
    "other_agency" => "Autre"
  }.freeze

  def agency_label
    AGENCY_LABELS[agency] || agency.humanize
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
    interim: "interim",
    cdi: "cdi",
    other_contract: "other_contract"
  }

  CONTRACT_TYPE_LABELS = {
    "cdd" => "CDD",
    "cidd" => "CIDD",
    "interim" => "Intérim",
    "cdi" => "CDI",
    "other_contract" => "Autre"
  }.freeze

  def contract_type_label
    CONTRACT_TYPE_LABELS[contract_type] || contract_type.humanize
  end

  # ============================================================
  # VALIDATIONS
  # ============================================================

  validates :night_rate, :ifm_rate, :cp_rate,
            numericality: { greater_than_or_equal_to: 0 }
  validates :km_rate, numericality: true, allow_nil: true
  validates :km_limit,
            numericality: { greater_than_or_equal_to: 0 }

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
end
