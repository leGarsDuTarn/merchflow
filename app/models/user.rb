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
  # RÔLE
  # ============================================================

  enum role: { merch: 0, fve: 1, admin: 2 }

# ============================================================
# PRÉFÉRENCES DE CONFIDENTIALITÉ + PREMIUM
# ============================================================

  # Attributs déclarés en DB (pas obligatoire mais utile pour clarity)
  attribute :allow_email, :boolean, default: false
  attribute :allow_phone, :boolean, default: false
  attribute :allow_identity, :boolean, default: false
  attribute :premium, :boolean, default: false

  # Conditions d'accès aux informations sensibles
  def can_view_contact?(viewer)
    return false unless viewer.present?
    return false unless viewer.fve?
    return false unless viewer.premium?

    true
  end

  # Affichage du nom
  def displayable_name(viewer)
    # Visible seulement si : identité autorisée + viewer premium FVE
    return username unless can_view_contact?(viewer) && allow_identity

    full_name
  end

  # Affichage de l'email
  def displayable_email(viewer)
    return nil unless can_view_contact?(viewer) && allow_email

    email
  end

  # Affichage du numéro
  def displayable_phone(viewer)
    return nil unless can_view_contact?(viewer) && allow_phone

    phone_number
  end

  # ============================================================
  # VALIDATIONS
  # ============================================================

  validates :firstname, presence: { message: 'Vous devez renseigner votre prénom' }
  validates :lastname,  presence: { message: 'Vous devez renseigner votre nom' }

  validates :username,
            presence: { message: "Vous devez choisir un nom d'utilisateur" },
            uniqueness: { message: "Ce nom d'utilisateur est déjà pris" },
            format: {
              with: /\A[a-zA-Z0-9._-]+\z/,
              message: 'ne peut contenir que des lettres, chiffres, . _ ou -'
            }

  validates :email,
            presence: { message: 'Veuillez renseigner un email.' },
            format: { with: URI::MailTo::EMAIL_REGEXP, message: 'exemple : john@gmail.com' },
            uniqueness: { message: 'Cette adresse email est déjà utilisée' }

  validates :phone_number,
            allow_blank: true,
            format: {
              with: /\A0[67]\d{8}\z/,
              message: 'Numéro invalide, ex 0612233614'
            }

  validates :address, presence: { message: 'Vous devez renseigner une adresse' }
  validates :zipcode, presence: { message: 'Vous devez renseigner un code postal' }
  validates :city,    presence: { message: 'Vous devez renseigner une ville' }

  # ============================================================
  # MOT DE PASSE FORT
  # ============================================================
  VALID_PASSWORD_REGEX = /\A
    (?=.*[a-z])        # Au moins une minuscule
    (?=.*[A-Z])        # Au moins une majuscule
    (?=.*\d)           # Au moins un chiffre
    (?=.*[[:^alnum:]]) # Au moins un caractère spécial
    .{8,}              # PUIS on consomme 8+ caractères
  \z/x

  validates :password,
            format: {
              with: VALID_PASSWORD_REGEX,
              message: 'Doit contenir au moins 8 caractères, dont une majuscule, une minuscule, un chiffre et un caractère spécial.'
            },
            if: :password_required?

  def password_required?
    new_record? || password.present? || password_confirmation.present?
  end

  # ============================================================
  # NORMALISATION DES CHAMPS
  # ============================================================
  before_validation :normalize_names
  before_validation :normalize_username
  before_validation :normalize_email
  before_validation :generate_username, on: :create
  before_validation :normalize_phone_number

  def normalize_names
    self.firstname = firstname.strip.downcase.capitalize if firstname.present?
    self.lastname  = lastname.strip.downcase.capitalize if lastname.present?
  end

  def normalize_username
    return if username.blank?

    cleaned = username.to_s.strip.downcase.gsub(/[^a-z0-9._-]/, '')
    self.username = cleaned if cleaned.present?
  end

  def normalize_email
    self.email = email.to_s.strip.downcase if email.present?
  end

  def generate_username
    return if username.present?

    base = "#{firstname}#{lastname}".downcase.gsub(/[^a-z0-9]/, '')
    base = 'user' if base.blank?

    candidate = base
    counter = 1

    while User.exists?(username: candidate)
      candidate = "#{base}#{counter}"
      counter += 1
    end

    self.username = candidate
  end

  def normalize_phone_number
    return if phone_number.blank?

    cleaned = phone_number.gsub(/\D/, '') # supprime tout sauf les chiffres

    # Transforme +33 en 0
    cleaned = cleaned.sub(/\A33/, '0') if cleaned.start_with?("33")

    self.phone_number = cleaned
  end

  # ============================================================
  # MÉTHODES UTILITAIRES
  # ============================================================
  def full_name
    "#{firstname.to_s.titleize} #{lastname.to_s.titleize}"
  end

  def full_address
    [address, zipcode, city].compact.join(', ')
  end

  def address_complete?
    address.present? && zipcode.present? && city.present?
  end

  # ============================================================
  # DASHBOARD — TOTAUX GLOBAUX
  # ============================================================
  def total_minutes_worked
    work_sessions.sum(&:duration_minutes)
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

  # ============================================================
  # DASHBOARD — TOTAUX DU MOIS EN COURS
  # ============================================================

  # Sessions du mois
  def sessions_this_month
    WorkSession
      .joins(:contract)
      .where(contracts: { user_id: id })
      .current_month
  end

  # Heures du mois
  def total_hours_this_month
    (sessions_this_month.sum(&:duration_minutes) / 60.0).round(2)
  end

  # Brut du mois
  def total_brut_this_month
    sessions_this_month.sum(&:brut)
  end

  # IFM + CP du mois
  def total_ifm_cp_this_month
    sessions_this_month.sum { |ws| ws.contract.ifm(ws.brut) + ws.contract.cp(ws.brut) }
  end

  # KM du mois
  def total_km_this_month
    sessions_this_month.sum(&:effective_km)
  end

  # Frais km remboursés du mois
  def total_km_payment_this_month
    sessions_this_month.sum(&:km_payment_final)
  end

  # Net estimé hors km
  def net_estimated_this_month
    (total_brut_this_month * 0.78).round(2)
  end

  # Net total estimé avec km
  def net_total_estimated_this_month
    (net_estimated_this_month + total_km_payment_this_month).round(2)
  end

  # Répartition par agence (mois)
  def total_by_agency_this_month
    sessions_this_month
      .includes(:contract)
      .group_by { |ws| ws.contract }
      .map do |contract, sessions|
        {
          agency: contract.agency_label,
          brut: sessions.sum(&:brut),
          hours: (sessions.sum(&:duration_minutes) / 60.0).round(2),
          km: sessions.sum(&:effective_km)
        }
      end
  end
end
