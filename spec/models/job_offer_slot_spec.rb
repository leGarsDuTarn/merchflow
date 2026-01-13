require 'rails_helper'

RSpec.describe JobOfferSlot, type: :model do
  # On a besoin d'une offre parente pour créer un slot
  let(:offer) { create(:job_offer) }

  describe 'Validations de base' do
    it 'est valide avec des horaires cohérents' do
      # 08h-12h avec pause 10h-11h
      slot = build(:job_offer_slot, job_offer: offer,
                   start_time: "08:00", end_time: "12:00",
                   break_start_time: "10:00", break_end_time: "11:00")
      expect(slot).to be_valid
    end

    it 'refuse un start_time identique à end_time (durée 0)' do
      slot = build(:job_offer_slot, job_offer: offer, start_time: "08:00", end_time: "08:00")
      expect(slot).not_to be_valid
      expect(slot.errors[:end_time]).to include("doit être strictement après l'heure de début")
    end
  end

  describe 'Cohérence des pauses (break_times_consistency)' do
    context 'Mission de Journée (ex: 08h - 12h)' do
      it 'refuse une pause qui commence après la fin de la mission' do
        slot = build(:job_offer_slot, job_offer: offer,
                     start_time: "08:00", end_time: "12:00",
                     break_start_time: "13:00", break_end_time: "13:30")
        expect(slot).not_to be_valid
        expect(slot.errors[:break_start_time]).to include("la pause doit être comprise dans les horaires de mission")
      end

      it 'refuse une pause qui finit avant le début de la mission' do
        slot = build(:job_offer_slot, job_offer: offer,
                     start_time: "10:00", end_time: "12:00",
                     break_start_time: "08:00", break_end_time: "09:00")
        expect(slot).not_to be_valid
        expect(slot.errors[:break_start_time]).to include("la pause doit être comprise dans les horaires de mission")
      end
    end

    context 'Mission de Nuit (ex: 22h - 04h)' do
      # C'est ici qu'on vérifie ton correctif ("le trou dans la raquette")

      it 'ACCEPTE une pause prise le soir (avant minuit)' do
        # Mission 22h-04h / Pause 23h-23h30 (OK)
        slot = build(:job_offer_slot, job_offer: offer,
                     start_time: "22:00", end_time: "04:00",
                     break_start_time: "23:00", break_end_time: "23:30")
        expect(slot).to be_valid
      end

      it 'ACCEPTE une pause prise le matin (après minuit)' do
        # Mission 22h-04h / Pause 02h-02h30 (OK)
        slot = build(:job_offer_slot, job_offer: offer,
                     start_time: "22:00", end_time: "04:00",
                     break_start_time: "02:00", break_end_time: "02:30")
        expect(slot).to be_valid
      end

      it 'REFUSE une pause hors des horaires (ex: après-midi)' do
        # Mission 22h-04h / Pause 14h-15h (KO)
        slot = build(:job_offer_slot, job_offer: offer,
                     start_time: "22:00", end_time: "04:00",
                     break_start_time: "14:00", break_end_time: "15:00")

        expect(slot).not_to be_valid
        expect(slot.errors[:break_start_time]).to include("la pause doit être comprise dans les horaires de mission")
      end
    end

    context 'Logique interne de la pause' do
      it 'refuse une pause dont la fin est avant le début' do
        slot = build(:job_offer_slot, job_offer: offer,
                     break_start_time: "12:30", break_end_time: "12:00")
        expect(slot).not_to be_valid
        expect(slot.errors[:break_end_time]).to include("doit être après le début de la pause")
      end
    end
  end
end
