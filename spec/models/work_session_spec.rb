require 'rails_helper'

RSpec.describe WorkSession, type: :model do

  # --- CORRECTIF INDISPENSABLE : CRÉATION DE LA DÉPENDANCE ---
  before(:each) do
    # Nécessaire car create(:work_session) -> crée un Contract -> qui valide l'existence de l'Agence
    Agency.find_or_create_by!(code: 'actiale', label: 'Actiale')
  end
  # -----------------------------------------------------------

  # ------------------------------------------------------------
  # FACTORY
  # ------------------------------------------------------------
  context 'Test de la factory' do
    it 'La factory est valide' do
      expect(build(:work_session)).to be_valid
    end
  end

  # ------------------------------------------------------------
  # ASSOCIATIONS
  # ------------------------------------------------------------
  context 'Test des associations' do
    it { should belong_to(:contract) }
    it { should have_many(:kilometer_logs).dependent(:destroy) }
  end

  # ------------------------------------------------------------
  # VALIDATIONS
  # ------------------------------------------------------------
  context 'Test des validations' do
    it { should validate_presence_of(:date).with_message('Ce champ est requis') }
    it { should validate_presence_of(:start_time).with_message('Ce champ est requis') }
    it { should validate_presence_of(:end_time).with_message('Ce champ est requis') }
    it { should validate_numericality_of(:hourly_rate).is_greater_than(0) }
  end

  # ------------------------------------------------------------
  # VALIDATION : end_after_start
  # ------------------------------------------------------------
  context 'Test de la logique end_after_start' do
    it 'est valide si end_time > start_time' do
      ws = build(:work_session, start_time: '10:00', end_time: '12:00')
      expect(ws).to be_valid
    end

    it 'ne crée pas d’erreur si end_time < start_time car le callback corrige' do
      ws = build(:work_session,
                 start_time: Time.zone.parse('12:00'),
                 end_time: Time.zone.parse('11:00'))
      ws.valid?
      expect(ws.errors[:end_time]).to be_empty
    end
  end

  # ------------------------------------------------------------
  # CALLBACK : ensure_end_time_is_on_correct_day
  # ------------------------------------------------------------
  describe 'Callback ensure_end_time_is_on_correct_day' do
    it 'ajoute 1 jour si la mission passe minuit' do
      ws = build(:work_session,
                 start_time: Time.zone.parse('21:00'),
                 end_time: Time.zone.parse('02:00'))
      ws.valid?
      expect(ws.end_time.day).to eq(ws.start_time.day + 1)
    end
  end

  # ------------------------------------------------------------
  # CALLBACK : normalize_decimal_fields
  # ------------------------------------------------------------
  describe 'Callback normalize_decimal_fields' do
    it 'remplace les virgules par des points pour les frais' do
      ws = build(:work_session,
                 fee_meal: '12,50',
                 fee_parking: '5,20',
                 fee_toll: '10,00',
                 hourly_rate: '11,88')

      ws.valid? # Déclenche le callback

      expect(ws.fee_meal).to eq(12.5)
      expect(ws.fee_parking).to eq(5.2)
      expect(ws.fee_toll).to eq(10.0)
      expect(ws.hourly_rate).to eq(11.88)
    end
  end

  # ------------------------------------------------------------
  # CALLBACK : compute_duration
  # ------------------------------------------------------------
  describe 'Callback compute_duration' do
    it 'calcule correctement la durée en minutes' do
      ws = build(:work_session,
                 start_time: Time.zone.parse('10:00'),
                 end_time: Time.zone.parse('12:30'))
      ws.valid?
      expect(ws.duration_minutes).to eq(150)
    end
  end

  # ------------------------------------------------------------
  # CALLBACK : compute_night_minutes
  # ------------------------------------------------------------
  describe 'Callback compute_night_minutes' do
    it 'compte les minutes entre 21h et 6h' do
      ws = build(:work_session,
                 start_time: Time.zone.parse('20:00'),
                 end_time: Time.zone.parse('22:00'))
      ws.valid?
      expect(ws.night_minutes).to eq(60)
    end

    it 'compte correctement la nuit en passant minuit' do
      ws = build(:work_session,
                 start_time: Time.zone.parse('23:00'),
                 end_time: Time.zone.parse('05:00'))
      ws.valid?
      expect(ws.night_minutes).to eq(360)
    end
  end

  # ------------------------------------------------------------
  # CALLBACK : compute_effective_km
  # ------------------------------------------------------------
  describe 'Callback compute_effective_km' do
    it 'utilise km_custom en priorité' do
      ws = build(:work_session, km_custom: 12.5)
      ws.valid?
      expect(ws.effective_km).to eq(12.5)
    end

    it 'somme les kilometer_logs si km_custom absent' do
      ws = create(:work_session, km_custom: nil)
      create(:kilometer_log, distance: 10, work_session: ws)
      create(:kilometer_log, distance: 5,  work_session: ws)

      ws.valid?
      expect(ws.effective_km).to eq(15.0)
    end

    it 'retourne 0 si aucun KM indiqué' do
      ws = build(:work_session, km_custom: nil)
      ws.valid?
      expect(ws.effective_km).to eq(0.0)
    end
  end

  # ------------------------------------------------------------
  # CALCUL BRUT
  # ------------------------------------------------------------
  describe 'Méthode brut' do
    it 'retourne 0 si duration_minutes = 0' do
      ws = build(:work_session, duration_minutes: 0)
      expect(ws.brut).to eq(0)
    end

    it 'calcule day + night' do
      contract = build(:contract, night_rate: 20)
      ws = build(:work_session,
                 contract: contract,
                 duration_minutes: 120,
                 night_minutes: 60,
                 hourly_rate: 10)
      # 1h jour (10€) + 1h nuit (12€) = 22€
      expect(ws.brut).to eq(22)
    end
  end

  # ------------------------------------------------------------
  # MÉTHODES NET & NET_TOTAL
  # ------------------------------------------------------------
  describe 'Test des méthodes net et net_total' do
    it 'calcule correctement le net (brut - 22%)' do
      ws = build(:work_session,
                 start_time: Time.zone.parse('10:00'),
                 end_time: Time.zone.parse('12:00'),
                 hourly_rate: 10) # Brut = 20€
      ws.valid?
      # 20 - (20 * 0.22) = 15.6
      expect(ws.net).to eq(15.6)
    end

    # --- NOUVEAU TEST D'INTÉGRATION (Correction du Bug KM) ---
    it 'calcule le net_total en prenant en compte le taux KM personnalisé (0.50)' do
      # On force un taux spécifique (0.50) sur le contrat
      # ET on active km_unlimited: true pour ne pas être bloqué par la limite de 40km de la Factory
      contract = create(:contract,
                        km_rate: 0.50,
                        km_unlimited: true,
                        night_rate: 0,
                        ifm_rate: 10,
                        cp_rate: 10)

      ws = build(:work_session,
                 contract: contract,
                 start_time: Time.zone.parse("10:00"),
                 end_time: Time.zone.parse("12:00"), # 2h
                 hourly_rate: 10.0,                  # Brut = 20€
                 km_custom: 100,                     # Utilise km_custom (100km * 0.50 = 50€)
                 fee_meal: 0,
                 fee_parking: 0)

      ws.valid? # Lance les calculs

      # 1. Vérifie que km_payment_final retourne bien 50€
      expect(ws.km_payment_final).to eq(50.0)

      # 2. Vérifie le total complet sans utiliser de Mock
      net_brut = ws.net                      # 15.6
      net_ifm  = (ws.amount_ifm * 0.78).round(2)
      net_cp   = (ws.amount_cp * 0.78).round(2)

      expected_total = (net_brut + net_ifm + net_cp + 50.0).round(2)

      expect(ws.net_total).to eq(expected_total)
    end
  end

  # ------------------------------------------------------------
  # total_payment (avec frais) - VERSION ROBUSTE (SANS MOCKS)
  # ------------------------------------------------------------
  describe 'Méthode total_payment' do
    it 'calcule correctement la somme : brut + ifm + cp + km + fees' do
      # 1. On configure un contrat clair (10% IFM, 10% CP, 0.50€/km)
      contract = create(:contract,
                        ifm_rate: 10.0,
                        cp_rate: 10.0,
                        km_rate: 0.50,
                        km_unlimited: true, 
                        night_rate: 0)

      # 2. On crée une session de 2h à 10€/h (Brut = 20€)
      # + 10km (5€) + 20€ de frais divers
      ws = build(:work_session,
                 contract: contract,
                 start_time: Time.zone.parse("10:00"),
                 end_time: Time.zone.parse("12:00"),
                 hourly_rate: 10.0,
                 km_custom: 10,       # 10 km * 0.50 = 5.0 €
                 fee_meal: 15,        # 15 €
                 fee_parking: 5,      # 5 €
                 fee_toll: 0)

      ws.valid? # Lance les calculs

      # 3. On calcule ce qu'on attend "en vrai"
      # Brut = 20.0
      # IFM  = 10% de 20 = 2.0
      # CP   = 10% de (20 + 2) = 2.2
      # KM   = 5.0
      # Fees = 20.0
      # TOTAL ATTENDU = 49.2

      expected_total = 20.0 + 2.0 + 2.2 + 5.0 + 20.0

      expect(ws.total_payment).to eq(expected_total)
    end
  end

  # ------------------------------------------------------------
  # IMPACT DES FRAIS SUR LE BRUT (Important !)
  # ------------------------------------------------------------
  describe 'Impact des frais' do
    it "n'augmente PAS le salaire brut" do
      ws = build(:work_session,
                 hourly_rate: 10,
                 start_time: '10:00',
                 end_time: '11:00', # 1h = 10€ Brut
                 fee_meal: 50)      # 50€ de frais

      ws.valid?
      expect(ws.brut).to eq(10.0) # Le brut doit rester 10€, pas 60€
    end

    it 'calcule correctement la somme des frais (total_fees)' do
      ws = build(:work_session, fee_meal: 10, fee_parking: 5.5, fee_toll: 2.5)
      expect(ws.total_fees).to eq(18.0)
    end
  end

  # ------------------------------------------------------------
  # SCOPE for_month (PLANNING)
  # ------------------------------------------------------------
  context 'Test des scopes du planning -> .for_month' do
    let(:user)     { create(:user) }
    let(:contract) { create(:contract, user: user) }

    let!(:ws1) do
      create(:work_session,
        contract: contract,
        date: Date.new(2025, 2, 5),
        start_time: '08:00',
        end_time: '12:00'
      )
    end

    let!(:ws2) do
      create(:work_session,
        contract: contract,
        date: Date.new(2025, 2, 15),
        start_time: '06:00',
        end_time: '09:00'
      )
    end

    let!(:previous_month) do
      create(:work_session,
        contract: contract,
        date: Date.new(2025, 1, 20)
      )
    end

    let!(:next_month) do
      create(:work_session,
        contract: contract,
        date: Date.new(2025, 3, 2)
      )
    end

    it 'retourne uniquement les missions du mois demandé' do
      expect(WorkSession.for_month(2025, 2)).to contain_exactly(ws1, ws2)
    end

    it 'exclut les missions du mois précédent' do
      expect(WorkSession.for_month(2025, 2)).not_to include(previous_month)
    end

    it 'exclut les missions du mois suivant' do
      expect(WorkSession.for_month(2025, 2)).not_to include(next_month)
    end

    it 'trie les missions par date et start_time' do
      expect(WorkSession.for_month(2025, 2)).to eq([ws1, ws2])
    end

    it 'gère correctement un changement d’année (décembre → janvier)' do
      dec = create(:work_session, contract: contract, date: Date.new(2024, 12, 29))
      jan = create(:work_session, contract: contract, date: Date.new(2025, 1, 5))

      expect(WorkSession.for_month(2024, 12)).to include(dec)
      expect(WorkSession.for_month(2024, 12)).not_to include(jan)
    end
  end
end
