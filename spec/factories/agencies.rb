# spec/factories/agencies.rb

FactoryBot.define do
  factory :agency do
    # Utilisation de sequence pour garantir l'unicité
    sequence(:code) { |n| "agence-test-#{n}" }
    sequence(:label) { |n| "Agence Test #{n}" }
  end
end
