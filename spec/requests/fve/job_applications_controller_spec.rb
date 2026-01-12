require 'rails_helper'

RSpec.describe "Fve::JobApplications", type: :request do
  let(:fve) { create(:user, :fve) }
  let(:offer) { create(:job_offer, fve: fve) }
  let(:merch) { create(:user, :merch) }
  let!(:application) { create(:job_application, job_offer: offer, merch: merch) }

  before { sign_in fve }

  describe "DELETE /destroy" do
    it "ne supprime pas mais passe en status rejected (archive)" do
      expect {
        delete fve_job_application_path(application)
      }.not_to change(JobApplication, :count)

      expect(application.reload.status).to eq('rejected')
      expect(response).to redirect_to(fve_job_offer_path(offer))
    end
  end
end
