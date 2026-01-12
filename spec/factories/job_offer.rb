FactoryBot.define do
  factory :job_offer do
    # On force l'utilisation du trait :fve pour l'association
    association :fve, factory: [:user, :fve]

    title { "Mission Merchandising" }
    description { "Ceci est une description de plus de 20 caractères pour valider le modèle." }
    mission_type { "merchandising" }
    contract_type { "CDD" }
    company_name { "Coca-Cola" }
    store_name { "Carrefour" }
    address { "12 rue de la Paix" }
    zipcode { "75001" }
    city { "Paris" }
    contact_email { "contact@test.com" }
    contact_phone { "0612345678" }
    start_date { Time.current + 1.day }
    end_date { Time.current + 2.days }
    hourly_rate { 13.50 } # > 12.02
    headcount_required { 1 }
    status { "published" }
    km_rate { 0.29 }
  end
end
