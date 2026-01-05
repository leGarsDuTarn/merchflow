class JobOffer < ApplicationRecord
  # --- CONSTANTES ---
  MISSION_TYPES = %w[merchandising animation].freeze
  CONTRACT_TYPES = %w[CDD CIDD Interim].freeze
  STATUSES = %w[draft published filled suspended].freeze

  # Heures définissant la nuit (Modifiable ici si besoin globalement)
  NIGHT_START = 21
  NIGHT_END   = 6

  # --- ASSOCIATIONS ---
  belongs_to :fve, class_name: 'User', foreign_key: 'fve_id'
  has_many :job_applications, dependent: :destroy
  has_many :candidates, through: :job_applications, source: :merch

  # --- VALIDATIONS ---
  validates :title, presence: true, length: { minimum: 5, maximum: 100 }
  validates :description, presence: true, length: { minimum: 20 }
  validates :mission_type, inclusion: { in: MISSION_TYPES }
  validates :contract_type, inclusion: { in: CONTRACT_TYPES }
  validates :company_name, presence: true
  validates :contact_email, presence: { message: "est obligatoire pour valider l'offre" },
                            format: { with: URI::MailTo::EMAIL_REGEXP, message: "ne semble pas être un email valide" }
  validates :contact_phone, presence: { message: "est obligatoire pour valider l'offre" },
                            format: { with: /\A0[1-9]\d{8}\z/, message: "doit contenir 10 chiffres (ex: 0612345678)" }
  validates :address, :city, :zipcode, presence: true
  validates :zipcode, format: { with: /\A\d{5}\z/, message: "doit contenir 5 chiffres" }
  validates :start_date, :end_date, presence: true
  validate :end_date_after_start_date
  validate :break_time_consistency
  validates :hourly_rate, numericality: { greater_than_or_equal_to: 12.02, message: "ne peut pas être inférieur au SMIC Brut (12.02 €)" }
  validates :night_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 3.0 }
  validates :headcount_required, numericality: { only_integer: true, greater_than: 0 }
  validates :km_rate, presence: { message: "est obligatoire (mettez 0 si non pris en charge)" },
                      numericality: { greater_than_or_equal_to: 0 }
  validates :km_limit, numericality: { greater_than: 0, allow_nil: true }

  # --- CALLBACKS ---
  before_save :set_department_code
  before_save :compute_duration_minutes
  before_save :normalize_status

  # --- SCOPES ---
  # Filtres de base
  scope :published, -> { where(status: 'published') }
  scope :upcoming,  -> { where("start_date >= ?", Date.today) }

  # Filtrage par Localisation (Texte libre : Ville ou CP)
  scope :by_location, ->(query) {
    if query.present?
      q = "%#{query}%"
      where("city ILIKE ? OR zipcode ILIKE ?", q, q)
    end
  }

  # Filtre par Département (Code strict ex: "81")
  scope :by_department, ->(dept_code) { where(department_code: dept_code) if dept_code.present? }

  # Filtre par Type de mission (merchandising / animation)
  scope :by_type, ->(type) { where(mission_type: type) if type.present? }

  # Filtre par Type de contrat (CDD, Interim...)
  scope :by_contract, ->(contract) { where(contract_type: contract) if contract.present? }

  # Filtre par Rémunération minimum
  scope :min_rate, ->(rate) { where("hourly_rate >= ?", rate.to_f) if rate.present? }

  # Filtre par Date de début (Missions commençant après X)
  scope :starting_after, ->(date) { where("start_date >= ?", date.to_date) if date.present? }

  # Ton scope intelligent pour le dashboard Merch (ne pas toucher)
  scope :relevant_for, ->(user) {
    wanted_types = []
    wanted_types << 'merchandising' if user.merch_setting.role_merch
    wanted_types << 'animation' if user.merch_setting.role_anim

    published
      .upcoming
      .where(mission_type: wanted_types)
      .where(department_code: user.merch_setting.preferred_departments)
      .order(start_date: :asc)
  }

  # --- MÉTHODES INTELLIGENTES ---

  def agency_label
    return "Non spécifié" if fve.nil? || fve.agency.blank?
    Agency.find_by(code: fve.agency)&.label || fve.agency
  end

  def duration_hours
    (duration_minutes / 60.0).round(2)
  end

  def estimated_total_brut
    night_mins = compute_night_minutes_estimation
    day_mins = duration_minutes - night_mins
    h_day = day_mins / 60.0
    h_night = night_mins / 60.0
    pay_day = h_day * hourly_rate
    pay_night = h_night * (hourly_rate * (1 + night_rate))
    (pay_day + pay_night).round(2)
  end

  private

  def set_department_code
    self.department_code = zipcode[0..1] if zipcode.present?
  end

  def compute_duration_minutes
    return unless start_date && end_date
    raw_minutes = ((end_date - start_date) / 60).to_i
    if break_start_time.present? && break_end_time.present?
      break_minutes = ((break_end_time - break_start_time) / 60).to_i
      self.duration_minutes = raw_minutes - break_minutes
    else
      self.duration_minutes = raw_minutes
    end
  end

  def normalize_status
    self.status ||= 'draft'
  end

  def compute_night_minutes_estimation
    return 0 unless start_date && end_date
    minutes = 0
    current = start_date
    while current < end_date
      unless in_break_estimation?(current)
        if current.hour >= NIGHT_START || current.hour < NIGHT_END
           minutes += 1
        end
      end
      current += 1.minute
    end
    minutes
  end

  def in_break_estimation?(time)
    return false unless break_start_time.present? && break_end_time.present?
    time >= break_start_time && time < break_end_time
  end

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?
    errors.add(:end_date, "doit être après la date de début") if end_date < start_date
  end

  def break_time_consistency
    if break_start_time.present? ^ break_end_time.present?
      errors.add(:base, "Pause : début et fin requis")
    end
    if break_start_time.present? && break_end_time.present?
      errors.add(:break_end_time, "doit être après le début de la pause") if break_end_time <= break_start_time
    end
  end
end
