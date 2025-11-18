class User < ApplicationRecord
  # ============================================================
  # DEVISE MODULES
  # ============================================================

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # ============================================================
  # RELATIONS
  # ============================================================

  has_many :contracts, dependent: :destroy
  has_many :work_sessions, through: :contracts
  has_many :declarations, dependent: :destroy

  # ============================================================
  # VALIDATIONS
  # ============================================================

  validates :firstname, presence: { message: "Vous devez renseigner votre prénom" }
  validates :lastname,  presence: { message: "Vous devez renseigner votre nom" }

  validates :username,
            presence: { message: "Vous devez choisir un nom d'utilisateur" },
            uniqueness: { message: "Ce nom d'utilisateur est déjà pris" },
            format: {
              with: /\A[a-zA-Z0-9._-]+\z/,
              message: "ne peut contenir que des lettres, chiffres, . _ ou -"
            }

  validates :email,
            presence: { message: "Veuillez renseigner un email." },
            format: {
              with: URI::MailTo::EMAIL_REGEXP,
              message: "exemple : john@gmail.com"
            },
            uniqueness: {
              message: "Cette adresse email est déjà utilisée"
            }

  validates :address, presence: { message: "Vous devez renseigner une adresse" }
  validates :zipcode, presence: { message: "Vous devez renseigner un code postal" }
  validates :city,    presence: { message: "Vous devez renseigner une ville" }

  # ============================================================
  # MOT DE PASSE FORT (compatible Devise)
  # ============================================================

  VALID_PASSWORD_REGEX = /\A
    (?=.{8,})            # Minimum 8 caractères
    (?=.*\d)             # Au moins un chiffre
    (?=.*[a-z])          # Au moins une minuscule
    (?=.*[A-Z])          # Au moins une majuscule
    (?=.*[[:^alnum:]])   # Au moins un caractère spécial
  \z/x

  validates :password,
            format: {
              with: VALID_PASSWORD_REGEX,
              message: 'Doit contenir au moins 8 caractères, dont une majuscule, une minuscule, un chiffre et un caractère spécial.'
            },
            if: :password_required?

  # Devise-friendly: permet de modifier le profil sans retaper un mot de passe
  def password_required?
    new_record? || password.present? || password_confirmation.present?
  end

  # ============================================================
  # NORMALISATION DES CHAMPS UTILISATEUR
  # ============================================================

  before_validation :normalize_names
  before_validation :normalize_username
  before_validation :normalize_email
  before_validation :generate_username, on: :create

  # ============================================================
  # MÉTHODES UTILITAIRES
  # ============================================================

  def full_name
    "#{firstname.to_s.titleize} #{lastname.to_s.titleize}"
  end

  def full_address
    [address, zipcode, city].compact.join(", ")
  end

  def address_complete?
    address.present? && zipcode.present? && city.present?
  end

  # ============================================================
  # DASHBOARD
  # ============================================================

  def total_minutes_worked
    work_sessions.sum(:duration_minutes)
  end

  def total_hours_worked
    (total_minutes_worked / 60.0).round(2)
  end

  def total_brut
    work_sessions.map(&:brut).sum
  end

  def total_ifm_cp
    work_sessions.sum { |ws| ws.contract.ifm_cp_total(ws.brut) }
  end

  def total_km
    work_sessions.sum { |ws| ws.effective_km.to_f }
  end

  def total_km_payment
    work_sessions.sum do |ws|
      ws.contract.km_payment(ws.effective_km.to_f, recommended: ws.recommended)
    end
  end

  def total_by_agency
    contracts.includes(:work_sessions).map do |contract|
      {
        agency: contract.agency_label,
        brut: contract.work_sessions.sum(&:brut),
        hours: (contract.work_sessions.sum(:duration_minutes) / 60.0).round(2),
        km: contract.work_sessions.sum(&:effective_km)
      }
    end
  end

  # ============================================================
  # PRIVATE
  # ============================================================

  private

  def normalize_names
    self.firstname = firstname.to_s.squish.titleize
    self.lastname  = lastname.to_s.squish.titleize
  end

  def normalize_username
    return if username.blank?

    self.username = username.to_s.strip.downcase.gsub(/[^a-z0-9._-]/, "")
  end

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def generate_username
    return if username.present?

    base = "#{firstname}#{lastname}".downcase.gsub(/[^a-z0-9]/, "")
    candidate = base
    counter = 1

    while User.exists?(username: candidate)
      candidate = "#{base}#{counter}"
      counter += 1
    end

    self.username = candidate
  end
end
