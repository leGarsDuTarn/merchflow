class User < ApplicationRecord
  # Importe les constantes et la logique d'agence
  include AgencyConstants

  # ============================================================
  # DEVISE MODULES
  # ============================================================
  devise :database_authenticatable, :registerable,
         :rememberable, :validatable

  # ============================================================
  # RELATIONS
  # ============================================================
  has_many :contracts, dependent: :destroy
  has_many :work_sessions, through: :contracts
  has_many :declarations, dependent: :destroy
  has_many :unavailabilities, dependent: :destroy
  has_one :merch_setting, dependent: :destroy, foreign_key: :user_id
  # Contrats où cet utilisateur agit comme le MERCH (prestataire)
  has_many :merch_contracts, class_name: 'Contract', foreign_key: 'merch_id', dependent: :nullify
  # Contrats où cet utilisateur agit comme le FVE (agence/facturier)
  has_many :fve_contracts, class_name: 'Contract', foreign_key: 'fve_id', dependent: :nullify
  # Propositions de Missions envoyées (FVE)
  has_many :sent_mission_proposals, class_name: 'MissionProposal', foreign_key: 'fve_id', dependent: :destroy
  # Propositions de Missions reçues (Merch)
  has_many :received_mission_proposals, class_name: 'MissionProposal', foreign_key: 'merch_id', dependent: :destroy
  has_many :favorites_given, class_name: "Favorite", foreign_key: :fve_id, dependent: :destroy
  has_many :favorite_merchs, through: :favorites_given, source: :merch
  has_many :favorites_received, class_name: "Favorite", foreign_key: :merch_id, dependent: :destroy
  has_many :fans, through: :favorites_received, source: :fve
  # ============================================================
  # RÔLE + ENUM
  # ============================================================
  after_initialize :set_default_role, if: :new_record?

  enum :role, { merch: 0, fve: 1, admin: 2 }, default: :merch

  # ============================================================
  # SCOPE
  # ============================================================

  # ============================================================
  # PRÉFÉRENCES DE CONFIDENTIALITÉ + PREMIUM
  # ============================================================

  # Conditions d'accès aux informations sensibles
  def can_view_contact?(viewer)
    return false unless viewer.present?
    # Seul un FVE peut potentiellement voir les informations
    return false unless viewer.fve?
    # Le FVE doit être premium
    return false unless viewer.premium?
    # L'utilisateur Merch doit avoir un MerchSetting (sécurité)
    return false unless merch_setting.present?

    true
  end

  # Affichage du nom
  def displayable_name(viewer)
    # Visible seulement si : identité autorisée + viewer premium FVE
    # Utilisation correcte de l'association merch_setting
    return username unless can_view_contact?(viewer) && merch_setting.allow_identity

    full_name
  end

  # Affichage de l'email
  def displayable_email(viewer)
    # Utilisation correcte du nom de la colonne
    return nil unless can_view_contact?(viewer) && merch_setting.allow_contact_email

    email
  end

  # Affichage du numéro
  def displayable_phone(viewer)
    # Utilisation correcte du nom de la colonne
    return nil unless can_view_contact?(viewer) && merch_setting.allow_contact_phone

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
            },
            unless: :fve?

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

  validates :address, presence: { message: 'Vous devez renseigner une adresse' }, unless: :fve?
  validates :zipcode, presence: { message: 'Vous devez renseigner un code postal' }, unless: :fve?
  validates :city,    presence: { message: 'Vous devez renseigner une ville' }, unless: :fve?
  # Validation : Un FVE doit obligatoirement avoir une agence
  validates :agency, presence: true, if: :fve?
  # Vérifie que le code de l'agence existe bien dans la table Agency
  validates :agency, inclusion: {
    in: ->(_user) { Agency.pluck(:code) },
    message: "%{value} n'est pas une agence valide."
  }, if: -> { agency.present? && fve? } # On valide seulement si c'est un FVE

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

  # Méthode utilitaire pour filtrer les WorkSessions par mois
  def work_sessions_for_month(target_date)
    start_date = target_date.beginning_of_month
    end_date = target_date.end_of_month

    # Utilise l'association work_sessions (qui utilise through: :contracts) et filtre par date
    work_sessions.where(date: start_date..end_date)
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
  # DASHBOARD — TOTAUX MENSUELS (CORRIGÉS)
  # ============================================================

  # Heures du mois
  def total_hours_for_month(target_date)
    (work_sessions_for_month(target_date).sum(&:duration_minutes) / 60.0).round(2)
  end

  # Brut du mois
  def total_brut_for_month(target_date)
    work_sessions_for_month(target_date).sum(&:brut)
  end

  # IFM + CP du mois
  def total_ifm_cp_for_month(target_date)
    work_sessions_for_month(target_date).sum { |ws| ws.contract.ifm(ws.brut) + ws.contract.cp(ws.brut) }
  end

  # KM du mois
  def total_km_for_month(target_date)
    work_sessions_for_month(target_date).sum(&:effective_km)
  end

  # Frais km remboursés du mois
  def total_km_payment_for_month(target_date)
    work_sessions_for_month(target_date).sum(&:km_payment_final)
  end

  # Net estimé hors km
  def net_estimated_for_month(target_date)
    (total_brut_for_month(target_date) * 0.78).round(2)
  end

  # Net total estimé avec km
  def net_total_estimated_for_month(target_date)
    (net_estimated_for_month(target_date) + total_km_payment_for_month(target_date)).round(2)
  end

  # Répartition par agence (mois)
  def total_by_agency_for_month(target_date)
    sessions = work_sessions_for_month(target_date)

    # Si aucune session n'est trouvée, retourner un Array vide.
    return [] unless sessions.any?

    sessions.includes(:contract)
            .group_by(&:contract)
            .map do |contract, contract_sessions|
              {
                agency: contract.agency_label,
                brut: contract_sessions.sum(&:brut), # Utilisation de contract_sessions
                hours: (contract_sessions.sum(&:duration_minutes) / 60.0).round(2), # Utilisation de contract_sessions
                km: contract_sessions.sum(&:effective_km)
              }
            end
  end

  private

  def set_default_role
    self.role ||= :merch
  end
end
