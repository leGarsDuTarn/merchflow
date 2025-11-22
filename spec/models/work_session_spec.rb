require 'rails_helper'

RSpec.describe WorkSession, type: :model do

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
      contract = build(:contract, night_rate: 0.20)

      ws = build(:work_session,
                 contract: contract,
                 duration_minutes: 120,
                 night_minutes: 60,
                 hourly_rate: 10)

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
                 hourly_rate: 10)

      ws.valid?
      expect(ws.net).to eq(15.6)
    end

    it 'calcule net + ifm + cp + km_payment_final' do
      contract = build(:contract, night_rate: 0, ifm_rate: 0, cp_rate: 0, km_rate: 0)

      ws = build(:work_session,
                 contract: contract,
                 start_time: Time.zone.parse("10:00"),
                 end_time: Time.zone.parse("12:00"),
                 night_minutes: 0,
                 hourly_rate: 10,
                 effective_km: 10)

      allow(contract).to receive(:ifm).and_return(5.0)
      allow(contract).to receive(:cp).and_return(5.0)
      allow(contract).to receive(:km_payment).and_return(7.0)

      ws.valid?

      net_ifm = 5.0 * 0.78
      net_cp  = 5.0 * 0.78

      expected_total = (ws.net + net_ifm + net_cp + 7.0).round(2)

      expect(ws.net_total).to eq(expected_total)
    end
  end

  # ------------------------------------------------------------
  # total_payment
  # ------------------------------------------------------------
  describe 'Méthode total_payment' do
    it 'calcule brut + ifm + cp + km' do
      contract = build(:contract)

      ws = build(:work_session,
                 contract: contract,
                 duration_minutes: 120,
                 night_minutes: 0,
                 hourly_rate: 10,
                 effective_km: 15)

      allow(contract).to receive(:ifm).and_return(5)
      allow(contract).to receive(:cp).and_return(5)
      allow(contract).to receive(:km_payment).and_return(7)

      expect(ws.total_payment).to eq(ws.brut + 5 + 5 + 7)
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
