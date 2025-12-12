FactoryBot.define do
  factory :favorite do
    # Permet d'associer automatiquement des utilisateurs valides
    association :fve, factory: [:user, :fve]   # Utilise le trait FVE
    association :merch, factory: :user         # Utilise un user standard
  end
end
