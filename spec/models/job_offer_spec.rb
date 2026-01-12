require 'rails_helper'

RSpec.describe JobOffer, type: :model do
  # On utilise 'build' pour ne pas sauvegarder en base sauf si nécessaire (plus rapide)
  let(:job_offer) { build(:job_offer) }

  describe 'Validations' do
    it 'est valide avec les attributs par défaut' do
      expect(job_offer).to be_valid
    end

    context 'Règles Financières' do
      it 'refuse un taux horaire inférieur au SMIC (12.02)' do
        job_offer.hourly_rate = 11.50
        expect(job_offer).not_to be_valid
        expect(job_offer.errors[:hourly_rate]).to include("Le taux ne peut pas être inférieur au SMIC (12.02 €)")
      end

      it 'accepte un taux horaire supérieur ou égal au SMIC' do
        job_offer.hourly_rate = 12.02
        expect(job_offer).to be_valid
      end
    end

    context 'Cohérence des Dates' do
      it 'refuse une date de fin avant la date de début' do
        job_offer.start_date = Date.tomorrow
        job_offer.end_date = Date.yesterday
        expect(job_offer).not_to be_valid
        expect(job_offer.errors[:end_date]).to include("doit être après la date de début")
      end
    end
  end

  describe 'Logique de Calcul des Heures (Slots)' do
    # On persiste l'offre pour lui attacher des slots
    let(:offer) { create(:job_offer) }

    before do
      # Nettoyage des slots créés par la factory par défaut pour ce test précis
      offer.job_offer_slots.destroy_all
    end

    it 'calcule le total des heures réelles (real_total_hours)' do
      # 08:00 -> 12:00 (4h)
      create(:job_offer_slot, job_offer: offer, start_time: "08:00", end_time: "12:00", break_start_time: nil, break_end_time: nil)
      # 14:00 -> 18:00 (4h)
      create(:job_offer_slot, job_offer: offer, date: Date.tomorrow, start_time: "14:00", end_time: "18:00", break_start_time: nil, break_end_time: nil)

      expect(offer.reload.real_total_hours).to eq(8.0)
    end

    it 'déduit correctement les pauses' do
      # 08:00 -> 17:00 (9h) avec 1h de pause = 8h travaillées
      create(:job_offer_slot, job_offer: offer, start_time: "08:00", end_time: "17:00", break_start_time: "12:00", break_end_time: "13:00")

      expect(offer.reload.real_total_hours).to eq(8.0)
    end

    it 'calcule les heures de nuit (total_night_hours)' do
      offer.update(night_start: 21, night_end: 6) # Nuit standard

      # Slot de 18:00 à 23:00 (5h total dont 2h de nuit : 21h-23h)
      create(:job_offer_slot, job_offer: offer, start_time: "18:00", end_time: "23:00", break_start_time: nil, break_end_time: nil)

      expect(offer.reload.total_night_hours).to eq(2.0)
    end
  end

  describe 'Scopes de Recherche (Search)' do
    before do
      create(:job_offer, title: "Mission Alpha", city: "Paris")
      create(:job_offer, title: "Mission Beta", city: "Lyon")
    end

    it 'filtre par requête texte' do
      expect(JobOffer.by_query("Alpha").count).to eq(1)
      expect(JobOffer.by_query("Paris").count).to eq(1)
      expect(JobOffer.by_query("Marseille").count).to eq(0)
    end
  end

  describe 'place restante' do
    let(:offer) { create(:job_offer, headcount_required: 3) }

    it 'décrémente quand un candidat est accepté' do
      create(:job_application, job_offer: offer, status: 'accepted')
      expect(offer.remaining_spots).to eq(2)
    end

    it 'ne change pas pour les candidats en attente' do
      create(:job_application, job_offer: offer, status: 'pending')
      expect(offer.remaining_spots).to eq(3)
    end
  end

  context 'gestion des candidatures' do
    let(:offer) { create(:job_offer, headcount_required: 1) }

    it 'calcule correctement le nombre de places même en cas de dépassement' do
      create_list(:job_application, 2, job_offer: offer, status: 'accepted')
      expect(offer.remaining_spots).to eq(0)
    end

    it 'recalcule remaining_spots correctement après annulation' do
      app = create(:job_application, job_offer: offer, status: 'accepted')
      expect(offer.remaining_spots).to eq(0)
      app.update(status: 'pending')
      expect(offer.remaining_spots).to eq(1)
    end
  end

  context 'validation des créneaux (Slots)' do
    let(:offer) { create(:job_offer) }

    it 'accepte un slot valide' do
      # 08h-12h avec pause 10h-11h 
      slot = build(:job_offer_slot, job_offer: offer,
                   start_time: "08:00", end_time: "12:00",
                   break_start_time: "10:00", break_end_time: "11:00")
      expect(slot).to be_valid
    end

    it 'refuse un start_time identique à end_time' do
      slot = build(:job_offer_slot, job_offer: offer, start_time: "08:00", end_time: "08:00")
      expect(slot).not_to be_valid
      expect(slot.errors[:end_time]).to include("doit être strictement après l'heure de début")
    end

    it 'refuse un start_time après end_time' do
      slot = build(:job_offer_slot, job_offer: offer, start_time: "10:00", end_time: "08:00")
      expect(slot).not_to be_valid
    end

    it 'refuse une pause qui sort des horaires de la mission' do
      # Mission 08h-12h / Pause 13h-14h
      slot = build(:job_offer_slot, job_offer: offer,
                   start_time: "08:00", end_time: "12:00",
                   break_start_time: "13:00", break_end_time: "14:00")
      expect(slot).not_to be_valid
      expect(slot.errors[:break_start_time]).to include("la pause doit être comprise dans les horaires de mission")
    end

    it 'refuse une pause dont la fin est avant le début' do
      slot = build(:job_offer_slot, job_offer: offer,
                   break_start_time: "12:30", break_end_time: "12:00")
      expect(slot).not_to be_valid
      expect(slot.errors[:break_end_time]).to include("doit être après le début de la pause")
    end
  end
end
