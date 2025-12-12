require 'rails_helper'

RSpec.describe "Fve::Merches", type: :request do
  before { Agency.find_or_create_by!(code: 'actiale', label: 'Actiale') }

  let(:fve) { create(:user, :fve, agency: 'actiale') }
  let(:merch) { create(:user, role: :merch) }

  before do
    sign_in fve, scope: :user
  end

  describe "GET /index" do
    it "returns http success" do
      # Correspond à la route : fve_merch_index GET /fve/merch
      get "/fve/merch"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      # Correspond à la route : fve_merch GET /fve/merch/:id
      get "/fve/merch/#{merch.id}"
      expect(response).to have_http_status(:success)
    end
  end
end
