require 'rails_helper'

RSpec.describe "Fve::Dashboards", type: :request do
  # Setup des données
  before { Agency.find_or_create_by!(code: 'actiale', label: 'Actiale') }
  let(:fve) { create(:user, :fve, agency: 'actiale') }

  before do
    sign_in fve, scope: :user
  end

  describe "GET /index" do
    it "returns http success" do
      # Correspond à la route : fve_dashboard GET /fve/dashboard
      get "/fve/dashboard"
      expect(response).to have_http_status(:success)
    end
  end
end
