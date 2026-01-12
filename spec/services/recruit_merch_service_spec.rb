require 'rails_helper'

RSpec.describe RecruitMerchService, type: :service do
  let(:fve) { create(:user, :fve) }
  let(:offer) { create(:job_offer, fve: fve, headcount_required: 1) }

  let!(:slot) do
    create(
      :job_offer_slot,
      job_offer: offer,
      date: Date.tomorrow,
      start_time: "08:00",
      end_time: "12:00"
    )
  end

  let(:merch_1) { create(:user, :merch) }
  let(:merch_2) { create(:user, :merch) }

  let!(:application_1) { create(:job_application, job_offer: offer, merch: merch_1) }
  let!(:application_2) { create(:job_application, job_offer: offer, merch: merch_2) }

  describe '#call' do
    context 'quand tout est valide (Succès)' do
      subject(:service) { described_class.new(application_1) }

      before { offer.reload }

      it 'recrute le candidat et crée les documents' do
        expect {
          service.call
        }.to change(Contract, :count).by(1)
         .and change(WorkSession, :count).by(1)

        expect(application_1.reload.status).to eq('accepted')
      end

      it 'refuse automatiquement les autres candidatures si l’offre devient complète' do
        service.call
        expect(application_2.reload.status).to eq('rejected')
      end
    end

    context 'quand il y a un conflit d’agenda (Sécurité)' do
      it 'échoue si le merch a déjà une mission sur le même créneau' do
        other_contract = create(:contract, user: merch_1, agency: fve.agency)

        create(
          :work_session,
          contract: other_contract,
          date: Date.tomorrow,
          start_time: "09:00",
          end_time: "11:00",
          status: :accepted
        )

        offer.reload
        service = described_class.new(application_1)

        expect {
          expect(service.call).to be false
        }.not_to change(WorkSession, :count)

        expect(service.error_message).to include("chevauche une autre mission")
        expect(application_1.reload.status).to eq("pending")
      end

      it 'échoue si le merch a posé une indisponibilité ce jour-là' do
        test_date = Date.tomorrow
        slot.update!(date: test_date)

        create(:unavailability, user: merch_1, date: test_date)

        offer.reload
        service = described_class.new(application_1)

        expect(service.call).to be false
        expect(service.error_message).to include("indisponibilité")
        expect(application_1.reload.status).to eq("pending")
      end
    end

    context 'quand le merch est déjà recruté sur une autre offre au même créneau' do
      let(:other_fve) { create(:user, :fve) }
      let(:other_offer) { create(:job_offer, fve: other_fve, headcount_required: 1) }

      let!(:other_slot) do
        create(
          :job_offer_slot,
          job_offer: other_offer,
          date: Date.tomorrow,
          start_time: "08:00",
          end_time: "12:00"
        )
      end

      let!(:existing_contract) do
        create(:contract, user: merch_1, agency: other_fve.agency)
      end

      let!(:existing_work_session) do
        create(
          :work_session,
          contract: existing_contract,
          date: Date.tomorrow,
          start_time: "08:00",
          end_time: "12:00",
          status: :accepted
        )
      end

      let!(:other_application) do
        create(
          :job_application,
          job_offer: other_offer,
          merch: merch_1,
          status: "accepted"
        )
      end

      it 'refuse le recrutement pour éviter un double booking inter-offres' do
        offer.reload
        service = described_class.new(application_1)

        expect {
          expect(service.call).to be false
        }.not_to change(WorkSession, :count)

        expect(service.error_message).to include("chevauche une autre mission")
        expect(application_1.reload.status).to eq("pending")
      end
    end

    context 'quand la candidature est déjà traitée' do
      it 'empêche de recruter deux fois le même candidat' do
        application_1.update!(status: 'accepted')
        service = described_class.new(application_1)

        expect(service.call).to be false
        expect(service.error_message).to include("déjà été recruté")
      end
    end
  end
end
