require 'rails_helper'

RSpec.describe RecruitMerchService, type: :service do
  let(:fve) { create(:user, :fve) }
  # On crée une offre avec 1 place et un slot (créneau)
  let(:offer) { create(:job_offer, fve: fve, headcount_required: 1) }
  let!(:slot) { create(:job_offer_slot, job_offer: offer, date: Date.tomorrow, start_time: "08:00", end_time: "12:00") }

  let(:merch_1) { create(:user, :merch) }
  let(:merch_2) { create(:user, :merch) }

  let!(:application_1) { create(:job_application, job_offer: offer, merch: merch_1) }
  let!(:application_2) { create(:job_application, job_offer: offer, merch: merch_2) }

  describe '#call' do
    context 'quand tout est valide (Succès)' do
      subject { RecruitMerchService.new(application_1) }

      it 'recrute le candidat et crée les documents' do
        expect { subject.call }.to change(Contract, :count).by(1)
                               .and change(WorkSession, :count).by(1)

        expect(application_1.reload.status).to eq('accepted')
      end

      it 'refuse automatiquement les autres si l\'offre devient complète' do
        subject.call
        expect(application_2.reload.status).to eq('rejected')
      end
    end

    context 'quand il y a un conflit d\'agenda (Sécurité)' do
      it 'échoue si le merch a déjà une mission sur le même créneau' do
        # On crée une autre mission qui chevauche
        other_contract = create(:contract, user: merch_1, agency: fve.agency)
        create(:work_session, contract: other_contract, date: Date.tomorrow, start_time: "09:00", end_time: "11:00", status: :accepted)

        service = RecruitMerchService.new(application_1)
        expect(service.call).to be false
        expect(service.error_message).to include("déjà en mission")
      end

      it 'échoue si le merch a posé une indisponibilité ce jour-là' do
        create(:unavailability, user: merch_1, date: Date.tomorrow)

        service = RecruitMerchService.new(application_1)
        expect(service.call).to be false
        expect(service.error_message).to include("indisponibilité")
      end
    end

    context 'quand la candidature est déjà traitée' do
      it 'empêche de recruter deux fois le même' do
        application_1.update(status: 'accepted')
        service = RecruitMerchService.new(application_1)

        expect(service.call).to be false
        expect(service.error_message).to include("déjà été recruté")
      end
    end
  end
end
