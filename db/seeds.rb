puts "🌱 Reset de la base..."
User.destroy_all
Contract.destroy_all
WorkSession.destroy_all

# ============================================
# 👤 1 — Création de l'utilisateur principal
# ============================================
puts "👤 Création de l'utilisateur…"

user = User.create!(
  firstname: "Benjamin",
  lastname: "Grassiano",
  username: "benji",
  email: "benjamin@example.com",
  address: "11 route d'Albi",
  zipcode: "81350",
  city: "Valderiès",
  password: "Password1!",
  password_confirmation: "Password1!"
)

puts "   ➜ Utilisateur créé : #{user.full_name}"

# ============================================
# 📄 2 — Contrats
# ============================================
puts "📄 Création des contrats…"

contract1 = Contract.create!(
  user: user,
  name: "Contrat Actiale",
  agency: :actiale,
  contract_type: :cdd,
  night_rate: 0.5,
  ifm_rate: 0.1,
  cp_rate: 0.1,
  km_rate: 0.29,
  km_limit: 40,
  km_unlimited: false
)

contract2 = Contract.create!(
  user: user,
  name: "Contrat CPM",
  agency: :cpm,
  contract_type: :interim,
  night_rate: 0.5,
  ifm_rate: 0.1,
  cp_rate: 0.1,
  km_rate: 0.32,
  km_limit: 35,
  km_unlimited: false
)

puts "   ➜ Contrats créés."

# ============================================
# 🏬 Magasins + Entreprises
# ============================================

magasins = [
  ["Carrefour Albi", "Route de Castres, 81000 Albi"],
  ["Leclerc Les Portes d'Albi", "Avenue de St Juéry, 81000 Albi"],
  ["Intermarché Valderiès", "Rue du Stade, 81350 Valderiès"],
  ["Lidl Carmaux", "Route de Rodez, 81400 Carmaux"],
  ["Auchan Cap Découverte", "81390 Monestiés"]
]

entreprises = [
  "PepsiCo",
  "Lindt & Sprüngli",
  "Carambar & Co",
  "Danone",
  "Ferrero",
  "Nestlé",
  "Red Bull",
  "Bonduelle"
]

# ============================================
# 🕒 Création 20 missions réalistes
# ============================================
puts "🕒 Création de 20 missions…"

def random_times
  start_hour = [7, 8, 9, 14].sample
  start_time = Time.zone.now.change(hour: start_hour, min: 0)
  end_time = start_time + [3.hours, 4.hours, 5.hours].sample
  [start_time, end_time]
end

20.times do
  store, store_addr = magasins.sample
  company = entreprises.sample

  contract = [contract1, contract2].sample

  start_t, end_t = random_times

  WorkSession.create!(
    contract: contract,
    date: rand(30).days.ago.to_date,
    start_time: start_t,
    end_time: end_t,
    hourly_rate: 11.88,
    km_custom: rand(5..40),
    store: store,
    store_full_address: store_addr,
    company: company,
    notes: ["Mise en rayon", "TG à installer", "Réassort rayon", "Inventaire", nil].sample,
    recommended: [true, false].sample
  )
end

puts "✅ 20 missions créées !"
puts "🎉 SEEDING TERMINE 🎉"
