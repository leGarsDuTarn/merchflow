require "test_helper"

class WorkSessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get work_sessions_index_url
    assert_response :success
  end

  test "should get show" do
    get work_sessions_show_url
    assert_response :success
  end

  test "should get new" do
    get work_sessions_new_url
    assert_response :success
  end

  test "should get edit" do
    get work_sessions_edit_url
    assert_response :success
  end
end
