class FveInvitation < ApplicationRecord
  # ============================================================
  # CALLBACKS
  # ============================================================
  before_create :generate_token
  before_create :set_expiration

  # ============================================================
  # VALIDATIONS
  # ============================================================

  validates :email,
            presence: { message: 'Vous devez renseigner un email.' },
            format: { with: URI::MailTo::EMAIL_REGEXP, message: 'Format email invalide.' }

  validates :token,
            presence: { message: 'Le token d’invitation est manquant.' },
            uniqueness: { message: 'Ce token existe déjà.' }

  validates :agency,
            presence: { message: "Vous devez indiquer le nom de l'agence FVE." }

  validates :expires_at,
            presence: { message: "La date d'expiration doit être définie." }

  validates :premium,
            inclusion: { in: [true, false], message: 'Valeur premium invalide.' }

  validates :used,
            inclusion: { in: [true, false], message: 'Valeur used invalide.' }

  # ============================================================
  # SCOPES
  # ============================================================

  scope :active, -> { where(used: false).where('expires_at > ?', Time.current) }

  # ============================================================
  # INSTANCE METHODS
  # ============================================================

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def usable?
    !used && !expired?
  end

  # ============================================================
  # PRIVATE
  # ============================================================

  private

  def generate_token
    self.token ||= SecureRandom.hex(16)
  end

  def set_expiration
    self.expires_at ||= 7.days.from_now
  end
end
