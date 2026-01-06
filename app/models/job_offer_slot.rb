class JobOfferSlot < ApplicationRecord
  belongs_to :job_offer

  # Validations pour être sûr qu'il y a bien les infos en obligatoire
  validates :date, :start_time, :end_time, presence: true
end
