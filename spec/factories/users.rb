FactoryBot.define do
  factory :user do
    firstname { "Benjamin" }
    lastname  { "Grassiano" }

    # Génération des valeurs uniques pour éviter les collisions
    sequence(:username) { |n| "user_#{n}" }
    sequence(:email) { |n| "user_#{n}@example.com" }

    password { "Password1!" }
    password_confirmation { "Password1!" }

    address   { "11 route d'Albi" }
    zipcode   { "81350" }
    city      { "Valderiès" }

    # Par défaut c'est un merch, pas besoin d'agence
    role { :merch }

    # Trait pour créer un Admin
    trait :admin do
      role { :admin }
    end

    # Trait pour créer un FVE
    trait :fve do
      role { :fve }
      agency { "actiale" }
    end
  end
end
