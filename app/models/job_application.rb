class JobApplication < ApplicationRecord
  belongs_to :job_offer
  belongs_to :user

  validates :user_id, uniqueness: { scope: :job_offer_id, message: "Vous avez déjà postulé à cette offre" }

  scope :pending, -> { where(status: 'pending') }
  scope :accepted, -> { where(status: 'accepted') }
end
