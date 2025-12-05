class Contract < ApplicationRecord
  # 1. On supprime ou commente l'include de l'ancien fichier
  # include AgencyConstants

  belongs_to :user
  belongs_to :fve, class_name: 'User', optional: true
  belongs_to :merch, class_name: 'User', optional: true
  has_many :work_sessions, dependent: :destroy
  has_many :declarations, dependent: :destroy

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

  # 3. Nouvelle Validation : On vérifie que le code existe en DB
  validates :agency, presence: { message: 'Vous devez sélectionner une agence' }
  validate :agency_must_exist_in_db

  # 4. Helper pour les listes déroulantes (Select) dans vos vues
  def self.agency_options
    # Renvoie un tableau : [["Actiale", "actiale"], ["RMA", "rma"], ...]
    Agency.where.not(code: 'other').order(:label).pluck(:label, :code)
  end

  # 5. Méthode d'affichage (pour afficher "Actiale" au lieu de "actiale")
  def agency_label
    # Cherche le label en base, sinon affiche le code 'humanisé'
    Agency.find_by(code: agency)&.label || agency.to_s.humanize
  end

  def contract_type_label
    # Utilise le hash des labels pour retourner le nom lisible
    CONTRACT_TYPE_LABELS[contract_type] || contract_type.to_s.humanize
  end

  # ... Vos autres validations existantes (km_rate, etc.) ...
  validates :night_rate, :ifm_rate, :cp_rate, numericality: { greater_than_or_equal_to: 0 }
  validates :km_rate, presence: true, numericality: true
  validates :km_limit, numericality: { greater_than_or_equal_to: 0 }

  before_validation :normalize_decimal_fields

  private

  # La validation personnalisée
  def agency_must_exist_in_db
    return if agency.blank?
    # Si aucun enregistrement n'a ce code dans la table agencies -> erreur
    unless Agency.exists?(code: agency)
      errors.add(:agency, "n'est pas une agence valide")
    end
  end

  def normalize_decimal_fields
    %i[km_rate night_rate ifm_rate cp_rate].each do |field|
      value = self[field]
      next if value.blank?
      self[field] = value.to_s.tr(',', '.')
    end
  end
end
