class JobApplication < ApplicationRecord
  belongs_to :job_offer

  # On pointe vers 'merch_id' mais la classe reste 'User'
  belongs_to :merch, class_name: 'User', foreign_key: 'merch_id'

  # Validations
  validates :merch_id, uniqueness: { scope: :job_offer_id, message: "Vous avez déjà postulé à cette offre" }

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :accepted, -> { where(status: 'accepted') }
end
