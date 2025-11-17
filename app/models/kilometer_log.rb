class KilometerLog < ApplicationRecord
  # ============================================================
  # RELATIONS
  # ============================================================

  belongs_to :work_session

  # ============================================================
  # VALIDATIONS
  # ============================================================

  validates :distance,
            numericality: {
              greater_than_or_equal_to: 0,
              message: "ne peut pas être négative"
            }

  validates :km_rate,
            numericality: {
              greater_than: 0,
              message: "doit être supérieur à 0"
            }

  validates :description,
            length: { maximum: 255 }

  # ============================================================
  # CALLBACKS
  # ============================================================

  before_validation :normalize_description
  after_save :update_work_session_km
  after_destroy :update_work_session_km

  # ============================================================
  # NORMALISATION DES CHAMPS
  # ============================================================

  def normalize_description
    self.description = description.to_s.strip
  end

  # ============================================================
  # MÀJ DES KM DANS LA SESSION
  # ============================================================

  # Permet de recalculer automatiquement les km_effectifs dans WorkSession
  def update_work_session_km
    work_session.compute_effective_km
    work_session.save!
  end
end

