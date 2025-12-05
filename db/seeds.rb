# db/seeds.rb

# ============================================================
# 🔥 RESET DES DONNÉES
# ============================================================
puts "🔥 Nettoyage de la base de données..."

# Suppression des tables dépendantes des Merchandisers
WorkSession.joins(contract: :user).where(users: { role: :merch }).delete_all
puts "  ✓ Missions (WorkSession) supprimées"

MerchSetting.joins(:merch).where(users: { role: :merch }).delete_all
puts "  ✓ Paramètres de confidentialité supprimés"

Contract.joins(:user).where(users: { role: :merch }).delete_all
puts "  ✓ Contrats supprimés"

Unavailability.joins(:user).where(users: { role: :merch }).delete_all
puts "  ✓ Indisponibilités supprimées"

# CORRECTION DU BUG DE CLÉ ÉTRANGÈRE : Supprimer les propositions avant les utilisateurs
MissionProposal.where(merch_id: User.where(role: :merch).select(:id)).delete_all
puts "  ✓ Propositions de missions supprimées"

# Suppression des Merchandisers
User.where(role: :merch).delete_all
puts "  ✓ Merchandisers supprimés"

puts "  ℹ️  Admins et FVE préservés\n\n"

# ============================================================
# 🏢 CRÉATION DES AGENCES (Référentiel dynamique)
# ============================================================
puts "🏢 Initialisation du référentiel Agences..."

AGENCIES_DATA = {
  "actiale" => "Actiale",
  "rma" => "RMA SA",
  "edelvi" => "Edelvi",
  "mdf" => "DMF",
  "cpm" => "CPM",
  "idtt" => "Idtt Interim Distribution",
  "sarawak" => "Sarawak",
  "optimark" => "Optimark",
  "strada" => "Strada Marketing",
  "andeol" => "Andéol",
  "demosthene" => "Démosthène",
  "altavia" => "Altavia Fil Conseil",
  "marcopolo" => "MarcoPolo Performance",
  "virageconseil" => "Virage Conseil",
  "upsell" => "Upsell",
  "idal" => "iDal",
  "armada" => "Armada",
  "sellbytel" => "Sellbytel",
  "other" => "Autre / Non défini"
}

AGENCIES_DATA.each do |code, label|
  Agency.find_or_create_by!(code: code) do |a|
    a.label = label
  end
end
puts "  ✓ #{Agency.count} agences disponibles en base."


# ============================================================
# 📋 DONNÉES DE RÉFÉRENCE UTILISATEURS
# ============================================================

CITIES_FR = [
  ["Paris", "75000"], ["Lyon", "69000"], ["Marseille", "13000"],
  ["Nice", "06000"], ["Bordeaux", "33000"], ["Toulouse", "31000"],
  ["Nantes", "44000"], ["Lille", "59000"], ["Rennes", "35000"],
  ["Montpellier", "34000"], ["Strasbourg", "67000"], ["Grenoble", "38000"],
  ["Dijon", "21000"], ["Angers", "49000"], ["Rouen", "76000"],
  ["Reims", "51100"], ["Metz", "57000"], ["Caen", "14000"]
].freeze

SAMPLE_AGENCIES_CODES = %w[actiale rma edelvi cpm sarawak upsell].freeze

CONTACT_CHANNELS = %w[phone email message none].freeze
STORE_NAMES = ['Carrefour', 'Auchan', 'Leclerc', 'Casino', 'Intermarché'].freeze

CLIENT_COMPANIES = [
  "Panzani", "PepsiCo", "Carambar", "Coca Cola", "Bonduelle", "Barilla"
].freeze

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

def generate_phone
  "0#{[6, 7].sample}#{8.times.map { rand(0..9) }.join}"
end

# ============================================================
# 👷‍♂️ CRÉATION DES MERCHANDISERS
# ============================================================

nb_users = rand(50..80)
puts "\n👤 Création de #{nb_users} merchandisers..."

nb_users.times do |i|
  firstname = FIRSTNAMES.sample
  lastname = LASTNAMES.sample
  city, zipcode = CITIES_FR.sample

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
      role: :merch
    )
  rescue ActiveRecord::RecordInvalid
    # Ignore les erreurs de validation User (ex: email déjà pris), pour ne pas bloquer le seed
    next
  end

  # ============================================================
  # ⚙️ CRÉATION DES PARAMÈTRES ET CONTRATS
  # ============================================================
  role_merch = [true, false].sample
  role_anim = [true, false].sample
  role_merch = true if !role_merch && !role_anim
  share_planning_status = (rand(1..100) > 2)

  MerchSetting.create!(
    merch: user,
    allow_identity: [true, true, false].sample,
    share_address: [true, false].sample,
    share_planning: share_planning_status,
    allow_contact_email: [true, true, false].sample,
    allow_contact_phone: [true, false].sample,
    allow_contact_message: [true, false].sample,
    preferred_contact_channel: CONTACT_CHANNELS.sample,
    accept_mission_proposals: true,
    role_merch: role_merch,
    role_anim: role_anim
  )

  print "." if (i + 1) % 10 == 0

  rand(2..4).times do
    agency_code = SAMPLE_AGENCIES_CODES.sample
    agency_label = Agency.find_by(code: agency_code)&.label || agency_code.capitalize

    # Création du Contrat
    begin
      contract = Contract.create!(
        user: user,
        name: "Contrat #{agency_label} - #{city}",
        agency: agency_code,
        contract_type: :cdd,
        night_rate: 0.50,
        ifm_rate: 0.10,
        cp_rate: 0.10,
        km_rate: [0.29, 0.35].sample,
        km_limit: [40, 50, 60].sample,
        km_unlimited: [true, false, false].sample
      )
    rescue ActiveRecord::RecordInvalid
      # Ignore les erreurs de validation de Contrat (ex: nom de contrat déjà pris)
      next
    end


    # ============================================================
    # 📅 CRÉATION DES MISSIONS (avec WorkSession.create)
    # ============================================================
    # On utilise create au lieu de create! pour que les chevauchements échouent SANS planter le seed.

    nb_missions = rand(8..15)
    missions_creees = 0

    # On essaie de créer plus de missions que nécessaire, car certaines vont chevaucher
    rand(nb_missions..nb_missions + 5).times do
      date = rand(90.days.ago.to_date..Date.today)
      start_hour = [7, 8, 9, 13, 14].sample
      start_minute = [0, 15, 30].sample
      duration_hours = rand(3..7)

      start_time = Time.zone.parse("#{date} #{start_hour}:#{start_minute}")
      end_time = start_time + duration_hours.hours

      if WorkSession.create( # <-- CLÉ DE LA STABILITÉ : WorkSession.create
        contract: contract,
        date: date,
        start_time: start_time,
        end_time: end_time,
        hourly_rate: [12.50, 13.00, 13.50, 14.00, 15.00].sample,
        effective_km: rand(5..80),
        store: "Magasin #{STORE_NAMES.sample}",
        company: CLIENT_COMPANIES.sample,
        recommended: [true, false].sample,
        notes: ["Mission standard", "Mise en rayon", "Inventaire", nil].sample
      )
        missions_creees += 1
      end

      break if missions_creees >= nb_missions
    end
  end
end

# ============================================================
# 📊 RÉSUMÉ
# ============================================================

puts "\n\n✅ SEED TERMINÉ AVEC SUCCÈS !\n"
puts "=" * 50
puts "🏢 Agences en base : #{Agency.count}"
puts "👥 Merchandisers créés : #{User.merch.count}"
puts "📄 Contrats créés : #{Contract.count}"
puts "📅 Missions créées : #{WorkSession.count}"
puts "💼 FVE existants : #{User.fve.count}"
puts "=" * 50
