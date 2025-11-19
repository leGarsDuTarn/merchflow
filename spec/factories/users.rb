FactoryBot.define do
  factory :user do
    firstname { "Benjamin" }
    lastname  { "Grassiano" }
    username  { "legarsdutarn" }
    email     { Faker::Internet.email }

    password { "Password1!" }
    password_confirmation { "Password1!" }

    address   { "11 route d'Albi" }
    zipcode   { "81350" }
    city      { "Valderiès" }
  end
end
