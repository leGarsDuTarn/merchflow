class User < ApplicationRecord
  # Importe les constantes et la logique d'agence
  include AgencyConstants

  # ============================================================
  # DEVISE MODULES
  # ============================================================
  devise :database_authenticatable, :registerable,
         :rememberable, :validatable, :recoverable

  # ============================================================
  # RELATIONS
  # ============================================================
  has_many :contracts, dependent: :destroy
  has_many :work_sessions, through: :contracts
  has_many :declarations, dependent: :destroy
  has_many :unavailabilities, dependent: :destroy
  has_one :merch_setting, dependent: :destroy, foreign_key: :user_id

  has_many :merch_contracts, class_name: 'Contract', foreign_key: 'merch_id', dependent: :nullify
  has_many :fve_contracts, class_name: 'Contract', foreign_key: 'fve_id', dependent: :nullify

  has_many :sent_mission_proposals, class_name: 'MissionProposal', foreign_key: 'fve_id', dependent: :destroy
  has_many :received_mission_proposals, class_name: 'MissionProposal', foreign_key: 'merch_id', dependent: :destroy
  has_many :favorites_given, class_name: "Favorite", foreign_key: :fve_id, dependent: :destroy
  has_many :favorite_merchs, through: :favorites_given, source: :merch
  has_many :favorites_received, class_name: "Favorite", foreign_key: :merch_id, dependent: :destroy
  has_many :fans, through: :favorites_received, source: :fve
  has_many :created_job_offers, class_name: 'JobOffer', foreign_key: 'fve_id', dependent: :destroy
  has_many :job_applications, class_name: 'JobApplication', foreign_key: 'merch_id', dependent: :destroy

  # ============================================================
  # RÔLE + ENUM
  # ============================================================
  after_initialize :set_default_role, if: :new_record?

  enum :role, { merch: 0, fve: 1, admin: 2 }, default: :merch

  # ============================================================
  # PRÉFÉRENCES DE CONFIDENTIALITÉ + PREMIUM
  # ============================================================

  def can_view_contact?(viewer)
    return false unless viewer.present?
    return false unless viewer.fve?
    return false unless viewer.premium?
    return false unless merch_setting.present?

    true
  end

  def displayable_name(viewer)
    return username unless can_view_contact?(viewer) && merch_setting.allow_identity
    full_name
  end

  def displayable_email(viewer)
    return nil unless can_view_contact?(viewer) && merch_setting.allow_contact_email
    email
  end

  def displayable_phone(viewer)
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

  validates :agency, presence: true, if: :fve?
  validates :agency, inclusion: {
    in: ->(_user) { Agency.pluck(:code) },
    message: "%{value} n'est pas une agence valide."
  }, if: -> { agency.present? && fve? }

  # ============================================================
  # MOT DE PASSE FORT
  # ============================================================
  VALID_PASSWORD_REGEX = /\A
    (?=.*[a-z])
    (?=.*[A-Z])
    (?=.*\d)
    (?=.*[[:^alnum:]])
    .{8,}
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

    # Listes de mots en français pour un aspect sympathique et anonyme
    adjectifs = %w[rapide brave calme malin solaire agile joyeux discret zen epique]
    noms = %w[faucon renard nebuleuse riviere vague montagne foret lynx comete delta]

    loop do
      # On génère une combinaison aléatoire (ex: "zen-lynx-4289")
      adjectif = adjectifs.sample
      nom = noms.sample
      nombre = rand(1000..9999)
      candidate = "#{adjectif}-#{nom}-#{nombre}"

      # On vérifie si ce pseudonyme est déjà pris
      unless User.exists?(username: candidate)
        self.username = candidate
        break # On sort de la boucle dès qu'un pseudo libre est trouvé
      end
    end
  end

  def normalize_phone_number
    return if phone_number.blank?
    cleaned = phone_number.gsub(/\D/, '')
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

  def work_sessions_for_month(target_date)
    start_date = target_date.beginning_of_month
    end_date = target_date.end_of_month
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
    # CORRECTION : Calcul explicite pour s'assurer que CP est sur (Brut + IFM)
    work_sessions.sum do |ws|
      b = ws.brut
      i = ws.contract.ifm(b)
      c = ws.contract.cp(b + i)
      i + c
    end
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
  # DASHBOARD — TOTAUX MENSUELS (PRÉCIS & CORRIGÉS)
  # ============================================================

  # 1. Heures du mois (Précision décimale : 7.75 et pas 8.0)
  def total_hours_for_month(target_date)
    # On divise par 60.0 pour forcer le décimal
    # On ne fait pas de .round(0) ou .to_i pour garder 7.75
    minutes = work_sessions_for_month(target_date).sum(&:duration_minutes)
    (minutes / 60.0).round(2)
  end

  # 2. Brut de BASE (Juste les heures × taux)
  def total_base_brut_for_month(target_date)
    work_sessions_for_month(target_date).sum(&:brut)
  end

  # 3. Brut COMPLET (Heures + IFM + CP)
  # C'est ce montant qu'il faut afficher dans ton Badge "Brut"
  def total_complete_brut_for_month(target_date)
    work_sessions_for_month(target_date).sum do |ws|
      # On utilise les accesseurs précis de WorkSession
      ws.brut + ws.amount_ifm + ws.amount_cp
    end
  end

  # 4. KM du mois
  def total_km_for_month(target_date)
    work_sessions_for_month(target_date).sum(&:effective_km)
  end

  # 5. Paiement KM (Montant €)
  def total_km_payment_for_month(target_date)
    work_sessions_for_month(target_date).sum(&:km_payment_final)
  end

  # 6. NET TOTAL ESTIMÉ (Le VRAI calcul)
  # Au lieu d'estimer 78%, on additionne les nets précis de chaque session
  def net_total_estimated_for_month(target_date)
    work_sessions_for_month(target_date).sum(&:net_total)
  end

  # Répartition par agence (Nettoyé pour utiliser les nouvelles méthodes)
  def total_by_agency_for_month(target_date)
    sessions = work_sessions_for_month(target_date)
    return [] unless sessions.any?

    sessions.includes(:contract)
            .group_by { |ws| ws.contract.agency_label }
            .map do |agency_label, agency_sessions|

              # Calculs précis basés sur la somme des sessions
              total_hours = (agency_sessions.sum(&:duration_minutes) / 60.0).round(2)

              # Calcul des totaux financiers en additionnant les valeurs des sessions
              total_transfer = agency_sessions.sum(&:net_total).round(2)
              total_km_pay   = agency_sessions.sum(&:km_payment_final).round(2)

              # Pour le brut complet (Base + IFM + CP) de l'agence
              total_brut_complete = agency_sessions.sum { |ws| ws.brut + ws.amount_ifm + ws.amount_cp }

              {
                agency:         agency_label,
                hours:          total_hours,
                brut:           total_brut_complete, # Brut complet
                km:             agency_sessions.sum(&:effective_km),
                km_payment:     total_km_pay,
                net_salary:     (total_transfer - total_km_pay).round(2), # Net hors KM
                total_transfer: total_transfer # Net à virer
              }
            end
  end

  # ============================================================
  # WRAPPERS POUR LE DASHBOARD
  # ============================================================

  def sessions_this_month
    work_sessions_for_month(Date.current)
  end

  def total_hours_this_month
    total_hours_for_month(Date.current)
  end

  def total_brut_this_month
    total_brut_for_month(Date.current)
  end

  def net_estimated_this_month
    net_estimated_for_month(Date.current)
  end

  def net_total_estimated_this_month
    net_total_estimated_for_month(Date.current)
  end

  private

  def set_default_role
    self.role ||= :merch
  end
end
