# ============================================================
# 🔥 RESET DES DONNÉES MERCH UNIQUEMENT
# ============================================================
puts "🔥 Suppression des données merchandisers..."

# Supprimer dans l'ordre pour respecter les dépendances
WorkSession.joins(contract: :user).where(users: { role: :merch }).delete_all
puts "  ✓ Missions supprimées"

Contract.joins(:user).where(users: { role: :merch }).delete_all
puts "  ✓ Contrats supprimés"

User.where(role: :merch).delete_all
puts "  ✓ Merchandisers supprimés"

puts "  ℹ️  Admins et FVE préservés\n\n"

# ============================================================
# 📋 DONNÉES DE RÉFÉRENCE
# ============================================================

CITIES_FR = [
  ["Paris", "75000"], ["Lyon", "69000"], ["Marseille", "13000"],
  ["Nice", "06000"], ["Bordeaux", "33000"], ["Toulouse", "31000"],
  ["Nantes", "44000"], ["Lille", "59000"], ["Rennes", "35000"],
  ["Montpellier", "34000"], ["Strasbourg", "67000"], ["Grenoble", "38000"],
  ["Dijon", "21000"], ["Angers", "49000"], ["Rouen", "76000"],
  ["Reims", "51100"], ["Metz", "57000"], ["Caen", "14000"]
].freeze

AGENCIES = %w[actiale rma edelvi].freeze

FIRSTNAMES = %w[
  Lucas Hugo Adam Léo Tom Nathan Louis Enzo Nolan Raphaël
  Emma Léa Chloé Manon Jade Inès Zoé Lola Sarah Anaïs
  Paul Julien Maxime Arthur Noa Ethan Alice Camille Claire
].freeze

LASTNAMES = %w[
  Martin Bernard Dubois Laurent Robert Petit Moreau Simon Michel
  Garcia Leroy Roux Fontaine Rousseau Vincent Muller Lefèvre
  Faure André Mercier Boyer Blanchet Garnier Lefort Roger
].freeze

# Génération de numéro de téléphone français valide
def generate_phone
  "0#{[6, 7].sample}#{8.times.map { rand(0..9) }.join}"
end

# ============================================================
# 👷‍♂️ CRÉATION DES MERCHANDISERS
# ============================================================

nb_users = rand(50..80)
puts "👤 Création de #{nb_users} merchandisers...\n"

nb_users.times do |i|
  firstname = FIRSTNAMES.sample
  lastname = LASTNAMES.sample
  city, zipcode = CITIES_FR.sample

  # Nettoyer les accents pour l'email
  email_firstname = firstname.downcase.unicode_normalize(:nfkd).gsub(/[^\x00-\x7F]/, '')
  email_lastname = lastname.downcase.unicode_normalize(:nfkd).gsub(/[^\x00-\x7F]/, '')

  begin
    user = User.create!(
      firstname: firstname,
      lastname: lastname,
      email: "#{email_firstname}.#{email_lastname}#{rand(1000..9999)}@merch.fr",
      password: "Merch2025!",
      password_confirmation: "Merch2025!",
      address: "#{rand(1..200)} rue du Commerce",
      zipcode: zipcode,
      city: city,
      phone_number: generate_phone,
      role: :merch,

      # Confidentialité : mix réaliste
      allow_email: [true, false].sample,
      allow_phone: [true, false].sample,
      allow_identity: [true, true, false].sample # 2/3 acceptent
    )
  rescue ActiveRecord::RecordInvalid => e
    puts "\n❌ ERREUR lors de la création de l'utilisateur #{firstname} #{lastname}:"
    puts e.record.errors.full_messages.join(", ")
    raise
  end

  print "." if (i + 1) % 10 == 0

  # ============================================================
  # 📄 CRÉATION DES CONTRATS (2 à 4 par merch)
  # ============================================================

  rand(2..4).times do
    agency = AGENCIES.sample

    contract = Contract.create!(
      user: user,
      name: "Contrat #{agency.capitalize} - #{city}",
      agency: agency,
      contract_type: :cdd,
      night_rate: 0.50,
      ifm_rate: 0.10,
      cp_rate: 0.10,
      km_rate: [0.29, 0.35].sample,
      km_limit: [40, 50, 60].sample,
      km_unlimited: [true, false, false].sample # 1/3 illimité
    )

    # ============================================================
    # 📅 CRÉATION DES MISSIONS (8 à 15 par contrat)
    # ============================================================

    rand(8..15).times do
      # Date aléatoire dans les 90 derniers jours
      date = rand(90.days.ago.to_date..Date.today)

      # Heures de début réalistes
      start_hour = [7, 8, 9, 13, 14].sample
      start_minute = [0, 15, 30].sample

      # Durée réaliste (3h à 7h)
      duration_hours = rand(3..7)

      start_time = Time.zone.parse("#{date} #{start_hour}:#{start_minute}")
      end_time = start_time + duration_hours.hours

      WorkSession.create!(
        contract: contract,
        date: date,
        start_time: start_time,
        end_time: end_time,
        hourly_rate: [12.50, 13.00, 13.50, 14.00, 15.00].sample,
        effective_km: rand(5..80),
        store: "Magasin #{['Carrefour', 'Auchan', 'Leclerc', 'Casino', 'Intermarché'].sample}",
        company: agency.capitalize,
        recommended: [true, false].sample,
        notes: ["Mission standard", "Mise en rayon", "Inventaire", nil].sample
      )
    end
  end
end

# ============================================================
# 📊 RÉSUMÉ
# ============================================================

puts "\n\n✅ SEED TERMINÉ AVEC SUCCÈS !\n"
puts "=" * 50
puts "👥 Merchandisers créés : #{User.merch.count}"
puts "📄 Contrats créés : #{Contract.count}"
puts "📅 Missions créées : #{WorkSession.count}"
puts "💼 FVE existants : #{User.fve.count}"
puts "🔐 Admins existants : #{User.admin.count}"
puts "=" * 50
puts "\n💡 Mot de passe par défaut : Merch2025!"
puts "📧 Format email : prenom.nom####@merch.fr\n\n"
