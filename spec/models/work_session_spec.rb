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
  # VALIDATION end_after_start
  # ------------------------------------------------------------
  context 'Test de la logique end_after_start' do
    it 'est valide si end_time > start_time' do
      ws = build(:work_session, start_time: '10:00', end_time: '12:00')
      expect(ws).to be_valid
    end

    it 'ne crée PAS d’erreur si end_time < start_time car le callback corrige' do
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
  describe 'Test du callback - passage minuit' do
    it 'ajoute 1 jour si la mission passe minuit' do
      ws = build(:work_session,
                 start_time: Time.zone.parse('21:00'),
                 end_time: Time.zone.parse('02:00'))

      ws.valid?
      expect(ws.end_time.day).to eq(ws.start_time.day + 1)
    end

    it 'corrige automatiquement end_time si end_time < start_time' do
      ws = build(:work_session,
                 start_time: Time.zone.parse('12:00'),
                 end_time: Time.zone.parse('11:00'))

      ws.valid?

      expect(ws.errors[:end_time]).to be_empty
      expect(ws.end_time.day).to eq(ws.start_time.day + 1)
    end
  end

  # ------------------------------------------------------------
  # CALLBACK : compute_duration
  # ------------------------------------------------------------
  describe 'Test du callback - compute_duration' do
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
  context 'Test du callback - compute_night_minutes' do
    it 'calcule les minutes de nuit entre 21h et 6h' do
      ws = build(:work_session,
                 start_time: Time.zone.parse('20:00'),
                 end_time: Time.zone.parse('22:00'))

      ws.valid?

      expect(ws.night_minutes).to eq(60)
    end

    it 'compte correctement la nuit quand on passe minuit' do
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
  context 'Test du callback - compute_effective_km' do
    it 'prend km_custom en priorité' do
      ws = build(:work_session, km_custom: 12.5)
      ws.valid?
      expect(ws.effective_km).to eq(12.5)
    end

    it 'prend la somme des kilometer_logs si km_custom absent' do
      ws = create(:work_session, km_custom: nil)
      create(:kilometer_log, distance: 10, work_session: ws)
      create(:kilometer_log, distance: 5,  work_session: ws)

      ws.valid?
      expect(ws.effective_km).to eq(15.0)
    end

    it 'retourne 0 si rien renseigné' do
      ws = build(:work_session, km_custom: nil)
      ws.valid?
      expect(ws.effective_km).to eq(0.0)
    end
  end

  # ------------------------------------------------------------
  # CALCUL BRUT
  # ------------------------------------------------------------
  context 'Test de la méthode brut' do
    it 'retourne 0 si duration_minutes = 0' do
      ws = build(:work_session, duration_minutes: 0)
      expect(ws.brut).to eq(0)
    end

    it 'calcule correctement (day + night)' do
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
  # TOTAL PAYMENT
  # ------------------------------------------------------------
  describe 'Test de la méthode total_payment' do
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
end
