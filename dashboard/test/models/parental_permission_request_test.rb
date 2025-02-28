require "test_helper"

class ParentalPermissionRequestTest < ActiveSupport::TestCase
  test "UUIDs should exist" do
    request = create(:parental_permission_request)
    assert_not_nil request.uuid
  end

  test "required inputs are required" do
    assert_not build(:parental_permission_request, user: nil).valid? "user is required"
    assert_not build(:parental_permission_request, parent_email: nil).valid? "parent email is required"
  end
end
