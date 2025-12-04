# app/models/concerns/agency_constants.rb
module AgencyConstants
  extend ActiveSupport::Concern

  # ============================================================
  # CONSTANTES D'AGENCE (Copiées depuis Contract)
  # ============================================================

  AGENCY_ENUMS = {
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
  }.freeze

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

  # ============================================================
  # MÉTHODES PARTAGÉES
  # ============================================================

  included do
    # Si le modèle a la colonne 'agency', il obtient la méthode d'affichage.
    if column_names.include?('agency')
      # Définit la méthode agency_label pour le modèle
      def agency_label
        return "Agence inconnue" if agency.blank?
        AGENCY_LABELS[agency] || agency.to_s.humanize
      end
    end
  end
end
