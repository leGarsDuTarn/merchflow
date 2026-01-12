class JobApplication < ApplicationRecord
  belongs_to :job_offer, optional: true
  belongs_to :merch, class_name: 'User', foreign_key: 'merch_id'

  before_destroy :clean_work_sessions_before_destroy
  before_create :capture_job_offer_snapshot
  after_update :clean_work_sessions, if: :status_changed_to_not_accepted?

  validates :merch_id, uniqueness: { scope: :job_offer_id, message: "Vous avez déjà postulé à cette offre" }

  scope :pending, -> { where(status: 'pending') }
  scope :accepted, -> { where(status: 'accepted') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :archived, -> { where(status: 'archived') }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :by_year,   ->(year)   { where('EXTRACT(YEAR FROM created_at) = ?', year) if year.present? }
  scope :by_month,  ->(month)  { where('EXTRACT(MONTH FROM created_at) = ?', month) if month.present? }

  private

  def status_changed_to_not_accepted?
    status_before_last_save == 'accepted' && status != 'accepted'
  end

  def clean_work_sessions_before_destroy
    # Seulement si la candidature était acceptée
    return unless status == 'accepted'

    clean_work_sessions
  end

  def clean_work_sessions
    fve = job_offer.fve
    agency_code = fve.respond_to?(:agency) ? fve.agency : nil

    contract = Contract.find_by(
      user_id: merch_id,
      agency: agency_code
    )

    if contract
      sessions_to_delete = WorkSession.where(
        contract: contract,
        job_offer_id: job_offer_id
      )

      sessions_to_delete.destroy_all
    end
  end

  def capture_job_offer_snapshot
    return if job_offer.blank?

    self.job_title_snapshot     = job_offer.title
    self.company_name_snapshot  = job_offer.company_name
    self.agency_snapshot        = job_offer.agency_label
    self.contract_type_snapshot = job_offer.contract_type
    self.start_date_snapshot    = job_offer.start_date
    self.end_date_snapshot      = job_offer.end_date
    self.hourly_rate_snapshot   = job_offer.hourly_rate

    # On stocke le lieu proprement
    self.location_snapshot      = "#{job_offer.city} (#{job_offer.zipcode})"
  end
end
