class JobOffer < ApplicationRecord
  # --- CONSTANTES ---
  MISSION_TYPES = %w[merchandising animation].freeze
  CONTRACT_TYPES = %w[CDD CIDD Interim].freeze
  STATUSES = %w[draft published filled suspended archived].freeze

  # --- ASSOCIATIONS ---
  belongs_to :fve, class_name: 'User', foreign_key: 'fve_id'
  has_many :job_applications, dependent: :destroy
  has_many :candidates, through: :job_applications, source: :merch

  # Relation pour le planning flexible
  has_many :job_offer_slots, dependent: :destroy
  accepts_nested_attributes_for :job_offer_slots, allow_destroy: true, reject_if: :all_blank

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

  # Validations mises à jour pour le système dynamique
  validates :night_rate, numericality: { greater_than_or_equal_to: 0 }
  validates :night_start, presence: true, numericality: { only_integer: true, in: 0..23 }
  validates :night_end, presence: true, numericality: { only_integer: true, in: 0..23 }

  validates :headcount_required, numericality: { only_integer: true, greater_than: 0 }
  validates :km_rate, presence: { message: "est obligatoire (mettez 0 si non pris en charge)" },
                      numericality: { greater_than_or_equal_to: 0 }
  validates :km_limit, numericality: { greater_than: 0, allow_nil: true }

  # --- CALLBACKS ---
  before_validation :normalize_attributes
  before_validation :normalize_decimal_fields # AJOUT : Comme dans WorkSession
  before_validation :sync_dates_from_slots
  before_save :set_department_code
  before_save :compute_duration_minutes
  before_save :normalize_status

  # --- SCOPES ---
  scope :published, -> { where(status: 'published') }
  scope :upcoming,  -> { where("start_date >= ?", Date.today) }

  # --- SCOPES POUR L'ARCHIVAGE ---
  scope :active, -> { where.not(status: 'archived') }
  scope :archived, -> { where(status: 'archived') }

  # --- SCOPES DE RECHERCHE ---
  scope :by_query, ->(query) {
    if query.present?
      q = "%#{query}%"
      where("title ILIKE ? OR city ILIKE ? OR zipcode ILIKE ? OR store_name ILIKE ?", q, q, q, q)
    end
  }
  scope :by_department, ->(dept_code) { where(department_code: dept_code) if dept_code.present? }
  scope :by_type, ->(type) { where(mission_type: type) if type.present? }
  scope :by_contract, ->(contract) { where(contract_type: contract) if contract.present? }
  scope :min_rate, ->(rate) { where("hourly_rate >= ?", rate.to_f) if rate.present? }
  scope :starting_after, ->(date) { where("start_date >= ?", date.to_date) if date.present? }
  scope :by_store, ->(store) { where(store_name: store) if store.present? }
  scope :by_status, ->(status) { where(status: status) if status.present? }

  scope :relevant_for, ->(user) {
    wanted_types = []
    wanted_types << 'merchandising' if user.merch_setting.role_merch
    wanted_types << 'animation' if user.merch_setting.role_anim

    published
      .upcoming
      .where(mission_type: wanted_types)
      .where(department_code: user.merch_setting.preferred_departments)
      .active
      .order(start_date: :asc)
  }

  # --- MÉTHODES PUBLIQUES ---

  def agency_label
    return "Non spécifié" if fve.nil? || fve.agency.blank?
    Agency.find_by(code: fve.agency)&.label || fve.agency
  end

  def duration_hours
    (duration_minutes / 60.0).round(2)
  end

  # --- COUNTERS & FINANCE ---

  def recruited_count
    job_applications.where(status: 'accepted').count
  end

  def remaining_spots
    [headcount_required - recruited_count, 0].max
  end

  def pending_count
    job_applications.where(status: 'pending').count
  end

  # Calcul du Brut de base (Séparation Jour / Nuit DYNAMIQUE)
  def total_base_brut
    hours_total = real_total_hours
    hours_night = total_night_hours
    hours_day   = hours_total - hours_night

    pay_day = hours_day * hourly_rate

    # Conversion du taux utilisateur (ex: 25) en multiplicateur (ex: 1.25)
    # Divise par 100 car stocke un pourcentage entier/decimal comme dans ifm_rate
    multiplier = 1 + (night_rate.to_f / 100.0)

    pay_night = hours_night * (hourly_rate * multiplier)

    (pay_day + pay_night).round(2)
  end

  # Calcul des Primes (Cumulatif : CP sur Base + IFM)
  def total_primes_amount
    base = total_base_brut
    ifm  = base * (ifm_rate / 100.0)
    cp   = (base + ifm) * (cp_rate / 100.0)
    (ifm + cp).round(2)
  end

  def grand_total_brut
    (total_base_brut + total_primes_amount).round(2)
  end

  def estimated_net_salary
    (grand_total_brut * 0.78).round(2)
  end

  # --- CALCULS SHOW & HELPERS ---

  # Calcul précis des heures totales (basé sur les slots)
  def real_total_hours
    return (duration_minutes / 60.0).round(2) if job_offer_slots.empty?

    total_minutes = 0
    job_offer_slots.reject(&:marked_for_destruction?).each do |slot|
      # Calcul durée brute
      duration = ((slot.end_time - slot.start_time) / 60).to_i
      duration += 1440 if duration < 0 # Gestion minuit

      # Soustraction pause
      if slot.break_start_time.present? && slot.break_end_time.present?
        break_dur = ((slot.break_end_time - slot.break_start_time) / 60).to_i
        break_dur += 1440 if break_dur < 0
        duration -= break_dur
      end
      total_minutes += duration
    end
    (total_minutes / 60.0).round(2)
  end

  # Calcul précis des heures de nuit DYNAMIQUE
  def total_night_hours
    return 0.0 if job_offer_slots.empty?

    # Utilisation des colonnes DB
    cfg_start = night_start
    cfg_end   = night_end

    night_minutes = 0
    job_offer_slots.reject(&:marked_for_destruction?).each do |slot|
      current = slot.start_time
      end_t   = slot.end_time
      end_t   += 1.day if end_t <= current

      while current < end_t
        # Vérification si pause
        in_break = false
        if slot.break_start_time.present? && slot.break_end_time.present?
           break_start = slot.break_start_time
           break_end   = slot.break_end_time
           break_end   += 1.day if break_end <= break_start

           if current.strftime("%H:%M") >= break_start.strftime("%H:%M") && current < break_end
             in_break = true
           end
        end

        unless in_break
          h = current.hour

          # Logique dynamique : Plage horaire classique (21-06) ou inversée (00-05)
          is_night = if cfg_start > cfg_end
                       h >= cfg_start || h < cfg_end
                     else
                       h >= cfg_start && h < cfg_end
                     end

          night_minutes += 1 if is_night
        end
        current += 1.minute
      end
    end
    (night_minutes / 60.0).round(2)
  end

  def publisher_name
    fve.agency_label.presence || "#{fve.first_name} #{fve.last_name}"
  end

  private

  # Méthode issue de WorkSession pour gérer les virgules
  def normalize_decimal_fields
    fields_to_check = %i[hourly_rate night_rate ifm_rate cp_rate km_rate km_limit]

    fields_to_check.each do |field|
      # Vérifie si la colonne existe (sécurité) et lit la valeur brute
      if self.class.column_names.include?(field.to_s)
        raw_value = read_attribute_before_type_cast(field)
        if raw_value.is_a?(String) && raw_value.include?(',')
          self[field] = raw_value.tr(',', '.')
        end
      end
    end
  end

  def normalize_attributes
    self.title = title&.strip&.capitalize
    self.city = city&.strip&.upcase
    self.zipcode = zipcode&.strip
    self.address = address&.strip
    self.company_name = company_name&.strip
    self.store_name = store_name&.strip
    self.contact_email = contact_email&.strip&.downcase
  end

  def sync_dates_from_slots
    return if job_offer_slots.blank? || job_offer_slots.all?(&:marked_for_destruction?)
    valid_slots = job_offer_slots.reject(&:marked_for_destruction?)
    return if valid_slots.empty?

    first_slot = valid_slots.min_by { |s| [s.date, s.start_time] }
    last_slot  = valid_slots.max_by { |s| [s.date, s.end_time] }

    if first_slot && last_slot
      self.start_date = Time.zone.parse("#{first_slot.date} #{first_slot.start_time.strftime('%H:%M')}")
      self.end_date   = Time.zone.parse("#{last_slot.date} #{last_slot.end_time.strftime('%H:%M')}")
    end
  end

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
