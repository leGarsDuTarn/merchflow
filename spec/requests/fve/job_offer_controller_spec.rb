require 'rails_helper'

RSpec.describe "Fve::JobOffers", type: :request do
  let(:fve) { create(:user, :fve) }
  let(:offer) { create(:job_offer, fve: fve) }
  let(:merch) { create(:user, :merch) }
  let!(:application) { create(:job_application, job_offer: offer, merch: merch) }

  before { sign_in fve }

  describe "POST /accept_candidate" do
    it "appelle le RecruitMerchService et redirige" do
      post accept_candidate_fve_job_offer_path(offer, application_id: application.id)

      expect(response).to redirect_to(fve_job_offer_path(offer))
      expect(flash[:notice]).to be_present
    end
  end

  describe "POST /recover_candidate" do
    it "repêche un candidat refusé" do
      application.update(status: 'rejected')

      post recover_candidate_fve_job_offer_path(offer, application_id: application.id)

      expect(application.reload.status).to eq('pending')
      expect(response).to redirect_to(fve_job_offer_path(offer))
    end
  end
end
