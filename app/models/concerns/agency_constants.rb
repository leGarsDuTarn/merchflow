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

      # Définit la méthode agency_label pour le modèle.
      # Elle cherche désormais le label dans la table Agency
      # au lieu d'utiliser le Hash statique AGENCY_LABELS.
      def agency_label
        return "Non renseigné" if agency.blank?

        # Le code de l'agence (ex: 'actimum') est dans self.agency
        # On interroge la base de données.
        found_agency = Agency.find_by(code: agency)

        if found_agency
          # Si l'enregistrement est trouvé, on retourne le label saisi par l'admin
          found_agency.label
        else
          # Si l'agence n'est pas trouvée en DB, on retourne le code humanisé
          # (cas d'une ancienne donnée ou d'une erreur de saisie)
          agency.to_s.humanize
        end
      end

    end
  end
end
