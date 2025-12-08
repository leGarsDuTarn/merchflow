class Favorite < ApplicationRecord
  belongs_to :fve, class_name: "User"
  belongs_to :merch, class_name: "User"

  validates :fve_id, uniqueness: { scope: :merch_id, message: "Ce merch est déjà dans vos favoris" }
end
