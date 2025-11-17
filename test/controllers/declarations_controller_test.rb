require "test_helper"

class DeclarationsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get declarations_index_url
    assert_response :success
  end

  test "should get france_travail" do
    get declarations_france_travail_url
    assert_response :success
  end
end
