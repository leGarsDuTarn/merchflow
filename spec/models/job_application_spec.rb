require 'rails_helper'

RSpec.describe JobApplication, type: :model do
  let(:offer) { create(:job_offer, title: "Super Mission", hourly_rate: 14.50, city: "Bordeaux") }
  let(:merch) { create(:user, :merch) }

  describe 'Validations' do
    it 'empêche de postuler deux fois à la même offre' do
      create(:job_application, job_offer: offer, merch: merch)

      duplicate = build(:job_application, job_offer: offer, merch: merch)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:merch_id]).to include("Vous avez déjà postulé à cette offre")
    end
  end

  describe 'Callbacks (Snapshots)' do
    it 'copie les infos de l\'offre à la création (Snapshot)' do
      application = create(:job_application, job_offer: offer, merch: merch)

      # On vérifie que les champs snapshot sont remplis
      expect(application.job_title_snapshot).to eq("Super Mission")
      expect(application.hourly_rate_snapshot).to eq(14.50)
      expect(application.location_snapshot).to include("Bordeaux")
    end

    it 'garde les infos snapshot même si l\'offre change après' do
      application = create(:job_application, job_offer: offer, merch: merch)

      # L'agence modifie l'offre
      offer.update!(title: "Titre Modifié", hourly_rate: 12.02)

      # La candidature doit garder les anciennes valeurs (Preuve juridique)
      expect(application.job_title_snapshot).to eq("Super Mission")
      expect(application.hourly_rate_snapshot).to eq(14.50)
    end
  end
end
