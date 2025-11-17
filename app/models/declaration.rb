class Declaration < ApplicationRecord
  # ============================================================
  # RELATIONS
  # ============================================================

  belongs_to :user
  belongs_to :contract

  # ============================================================
  # VALIDATIONS
  # ============================================================

  validates :month,
            presence: true,
            inclusion: { in: 1..12, message: "mois invalide" }

  validates :year,
            presence: true,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 2000,
              message: "année invalide"
            }

  validates :employer_name,
            presence: { message: "le nom de l'employeur est obligatoire" }

  validates :total_minutes,
            numericality: {
              greater_than_or_equal_to: 0,
              message: "les minutes doivent être positives"
            }

  validates :brut_with_cp,
            numericality: {
              greater_than_or_equal_to: 0,
              message: "le montant doit être positif"
            }

  # Un utilisateur ne peut avoir qu’une déclaration/mois/employeur
  validates :user_id, uniqueness: {
    scope: [:year, :month, :contract_id],
    message: "une déclaration existe déjà pour ce mois et cet employeur"
  }

  # ============================================================
  # CALLBACKS
  # ============================================================

  before_validation :set_employer_name, on: :create

  # ============================================================
  # MÉTHODES UTILITAIRES
  # ============================================================

  # Heures décimales utilisées par France Travail
  def total_hours
    (total_minutes / 60.0).round(2)
  end

  # Format : mm/yyyy
  def period_label
    "#{month.to_s.rjust(2, '0')}/#{year}"
  end

  # Nom employeur même si le contrat a été supprimé plus tard
  def employer
    employer_name || contract&.agency_label || "Employeur inconnu"
  end

  # ============================================================
  # PRIVATE
  # ============================================================

  private

  # Remplit automatiquement le nom employeur
  def set_employer_name
    self.employer_name ||= contract&.agency_label
  end
end
