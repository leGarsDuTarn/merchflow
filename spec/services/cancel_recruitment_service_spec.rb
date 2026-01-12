require 'rails_helper'

RSpec.describe CancelRecruitmentService, type: :service do
  let(:fve) { create(:user, :fve) }
  let(:offer) { create(:job_offer, fve: fve, status: 'filled') }
  let(:merch) { create(:user, :merch) }

  # Etat initial : déjà recruté
  let!(:application) { create(:job_application, job_offer: offer, merch: merch, status: 'accepted') }
  let!(:contract) { create(:contract, user: merch, agency: fve.agency) }
  let!(:session) { create(:work_session, contract: contract, job_offer: offer) }

  describe '#call' do
    subject { CancelRecruitmentService.new(application) }

    it 'supprime les sessions de travail et libère la place' do
      expect { subject.call }.to change(WorkSession, :count).by(-1)

      expect(application.reload.status).to eq('pending')
      expect(offer.reload.status).to eq('published')
    end

    it 'ne supprime pas le contrat (réutilisable)' do
      expect { subject.call }.not_to change(Contract, :count)
    end

    it 'ne peut pas annuler une candidature non validée' do
      application.update(status: 'pending')
      expect(subject.call).to be false
      expect(subject.error_message).to include("n'est pas validée")
    end
  end
end
