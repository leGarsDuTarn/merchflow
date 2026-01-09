class JobApplication < ApplicationRecord
  belongs_to :job_offer
  belongs_to :merch, class_name: 'User', foreign_key: 'merch_id'

  before_destroy :clean_work_sessions_before_destroy
  after_update :clean_work_sessions, if: :status_changed_to_not_accepted?

  validates :merch_id, uniqueness: { scope: :job_offer_id, message: "Vous avez déjà postulé à cette offre" }

  scope :pending, -> { where(status: 'pending') }
  scope :accepted, -> { where(status: 'accepted') }
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

    # ✅ Recherche cohérente avec user_id + agency
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
end
