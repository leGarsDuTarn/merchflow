class Agency < ApplicationRecord
  # Une agence a un code unique (utilisé comme clé de liaison) et un label (nom affiché)
  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :label, presence: true

  # ============================================================
  # CALLBACKS
  # ============================================================
  before_validation :generate_code
  # On s'assure que le code est propre pour la DB (minuscules, tirets)
  before_validation :format_code

  private

  def generate_code
    # 1. Si le code est vide mais que le label est rempli
    if self.code.blank? && self.label.present?
      # On prend le label et on le transforme en "slug"
      # Ex: "Agence du Sud-Ouest" devient "agence-du-sud-ouest"
      self.code = self.label.parameterize
    end

    # 2. Sécurité supplémentaire : même si l'admin a rempli le code,
    # on s'assure qu'il est propre (pas d'espace, pas d'accent, minuscules)
    if self.code.present?
      self.code = self.code.parameterize
    end
  end

  def format_code
    return if self.code.blank?

    self.code = self.code.downcase.strip
  end
end
