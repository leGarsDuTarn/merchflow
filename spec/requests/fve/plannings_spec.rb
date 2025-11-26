require 'rails_helper'

RSpec.describe "Fve::Plannings", type: :request do
  describe "GET /show" do
    it "returns http success" do
      get "/fve/plannings/show"
      expect(response).to have_http_status(:success)
    end
  end

end
