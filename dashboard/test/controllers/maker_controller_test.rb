require 'test_helper'

class MakerControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  STUB_ENCRYPTION_KEY = SecureRandom.base64(Encryption::KEY_LENGTH / 8)

  setup do
    @student = create :student
    @teacher = create :teacher
    @admin = create :admin
    @school = create :school
    @school_maker_high_needs = create :school, :is_maker_high_needs_school

    # Create 3 versions of the devices unit where one is assigned to the user,
    # one is the version the user most recently made progress in, and the other
    # is the most recent version (for testing that MakerController.maker_script
    # prioritizes an assigned unit version over a unit the user has progress in
    # over the newest version).
    @assigned_devices_version = ensure_script 'devices-assigned', '2020'
    @recent_progress_devices_version = ensure_script 'devices-progress', '2021'
    @most_recent_devices_version = ensure_script 'devices-recent', '2022'

    Unit.clear_cache
    Cpa.stubs(:cpa_experience).
      with(any_parameters).
      returns(Cpa::NEW_USER_LOCKOUT)
  end

  test_redirect_to_sign_in_for :home

  test "home loads for student" do
    sign_in @student

    get :home

    assert_response :success
    assert_select '#maker-home'
  end

  test "home loads for teacher" do
    sign_in @teacher

    get :home

    assert_response :success
    assert_select '#maker-home'
  end

  test "shows latest stable devices version if it is assigned" do
    create :user_script, user: @student, script: @most_recent_devices_version, assigned_at: Time.now
    assert_includes @student.scripts, @most_recent_devices_version

    assert_equal @most_recent_devices_version, MakerController.maker_script(@student)
  end

  test "prioritizes assigned devices version to show user" do
    section = create :section, user: @teacher, script: @assigned_devices_version
    create :user_script, user: @student, script: @assigned_devices_version, assigned_at: Time.now
    section.students << @student
    recent_progress_script = create :user_script, user: @student, script: @recent_progress_devices_version, last_progress_at: Time.now
    assert_includes @student.scripts, @assigned_devices_version
    assert_equal recent_progress_script, @student.user_script_with_most_recent_progress

    assert_equal @assigned_devices_version, MakerController.maker_script(@student)
  end

  test "prioritizes recent progress in devices version to show user if no versions assigned" do
    recent_progress_script = create :user_script, user: @student, script: @recent_progress_devices_version, last_progress_at: Time.now
    assert_equal recent_progress_script, @student.user_script_with_most_recent_progress

    assert_equal @recent_progress_devices_version, MakerController.maker_script(@student)
  end

  test "defaults to newest stable devices version if user has no assignments or progress in any version" do
    assert_empty @student.scripts
    assert_empty @student.section_courses
    assert_nil @student.user_script_with_most_recent_progress

    assert_equal @most_recent_devices_version, MakerController.maker_script(@student)
  end

  test "apply: fails if unit_6_intention not provided" do
    sign_in @teacher
    assert_raises ActionController::ParameterMissing do
      post :apply
    end
  end

  test "apply: fails if user doesn't have an application" do
    sign_in @teacher
    post :apply, params: {unit_6_intention: 'no'}
    assert_response :not_found
  end

  test "apply: fails if school doesn't meet eligibility requirements" do
    sign_in @teacher
    create :circuit_playground_discount_application,
      user: @teacher,
      school: @school,
      full_discount: false # This should be true before submitting a unit 6 intention

    CircuitPlaygroundDiscountApplication.stubs(:studio_person_pd_eligible?).returns(true)
    CircuitPlaygroundDiscountApplication.stubs(:student_progress_eligible?).returns(true)

    post :apply, params: {unit_6_intention: 'no'}
    assert_response :forbidden
  end

  test "apply: fails if teacher doesn't meet eligibility requirements" do
    sign_in @teacher
    create :circuit_playground_discount_application,
      user: @teacher,
      school: @school,
      full_discount: true

    # These should be true before submitting a unit 6 intention
    CircuitPlaygroundDiscountApplication.stubs(:studio_person_pd_eligible?).returns(false)
    CircuitPlaygroundDiscountApplication.stubs(:student_progress_eligible?).returns(false)

    post :apply, params: {unit_6_intention: 'no'}
    assert_response :forbidden
  end

  test "apply: fails if nonsense unit_6_intention provided" do
    sign_in @teacher
    create :circuit_playground_discount_application,
      user: @teacher,
      school: @school_maker_high_needs,
      full_discount: true

    CircuitPlaygroundDiscountApplication.stubs(:studio_person_pd_eligible?).returns(true)
    CircuitPlaygroundDiscountApplication.stubs(:student_progress_eligible?).returns(true)

    assert_raises ArgumentError do
      post :apply, params: {unit_6_intention: 'not an answer'}
    end
  end

  test "apply: updates the application with the intention" do
    sign_in @teacher
    application = create :circuit_playground_discount_application,
      user: @teacher,
      school: @school_maker_high_needs,
      full_discount: true

    assert_nil application.unit_6_intention

    CircuitPlaygroundDiscountApplication.stubs(:studio_person_pd_eligible?).returns(true)
    CircuitPlaygroundDiscountApplication.stubs(:student_progress_eligible?).returns(true)

    post :apply, params: {unit_6_intention: 'no'}
    assert_response :success

    application.reload
    assert_equal 'no', application.unit_6_intention
  end

  test "schoolchoice: fails if no school id provided" do
    sign_in @teacher

    assert_raises ActionController::ParameterMissing do
      post :schoolchoice
    end
  end

  test "schoolchoice: fails if given a bad school_id" do
    sign_in @teacher

    assert_raises ActiveRecord::RecordNotFound do
      post :schoolchoice, params: {nces: 'asdf'}
    end
  end

  test "schoolchoice: fails if user already has an application with a selected school" do
    sign_in @teacher
    create :circuit_playground_discount_application,
      user: @teacher,
      school: @school,
      full_discount: true

    post :schoolchoice, params: {nces: @school.id}
    assert_response :forbidden
  end

  test "schoolchoice: Creates an application" do
    sign_in @teacher

    assert_creates CircuitPlaygroundDiscountApplication do
      post :schoolchoice, params: {nces: @school.id}
      assert_response :success
      expected = {"school_high_needs_eligible" => false}
      assert_equal expected, JSON.parse(@response.body)
    end
  end

  test "schoolchoice: Returns full discount when applicant from Alaska" do
    sign_in @teacher
    school_alaska = create(:school, state: 'AK')

    post :schoolchoice, params: {nces: school_alaska.id}
    application = CircuitPlaygroundDiscountApplication.find_by(user_id: @teacher)

    assert application.full_discount
  end

  test "schoolchoice: Returns full discount when applicant from Hawaii" do
    sign_in @teacher
    school_hawaii = create(:school, state: 'HI')

    post :schoolchoice, params: {nces: school_hawaii.id}
    application = CircuitPlaygroundDiscountApplication.find_by(user_id: @teacher)

    assert application.full_discount
  end

  test "schoolchoice: Returns no discount when school not in Alaska or Hawaii" do
    sign_in @teacher
    school_washington = create(:school, state: 'WA')

    post :schoolchoice, params: {nces: school_washington.id}
    application = CircuitPlaygroundDiscountApplication.find_by(user_id: @teacher)

    refute application.full_discount
  end

  test "display_code: does not display secret code if no current_user" do
    get :display_code
    assert_select "#maker_code", count: 1, value: nil
  end

  test "display_code: does not display secret code if no matching credential is found" do
    user = create :user, :clever_sso_provider
    sign_in user

    get :display_code
    assert_select "#maker_code", count: 1, value: nil
  end

  test "display_code: displays secret code if matching credential is found" do
    CDO.stubs(:properties_encryption_key).returns(STUB_ENCRYPTION_KEY)
    user = create :user, :google_sso_provider
    sign_in user

    get :display_code
    assert_select "#maker_code", count: 1, value: /.+/
  end

  test "complete: fails if not given a signature" do
    DCDO.stubs(:get).with('currently_distributing_discount_codes', false).returns(true)
    sign_in @teacher

    assert_raises ActionController::ParameterMissing do
      post :complete, params: {nces: 'asdf'}
    end
  end

  test "complete: fails if user doesnt have application" do
    DCDO.stubs(:get).with('currently_distributing_discount_codes', false).returns(true)
    sign_in @teacher
    post :complete, params: {signature: "My Name"}
    assert_response :not_found
  end

  test "complete: fails if application not in the right state" do
    DCDO.stubs(:get).with('currently_distributing_discount_codes', false).returns(true)
    sign_in @teacher

    # no intention to teach unit 6
    application = create :circuit_playground_discount_application,
      user_id: @teacher.id,
      unit_6_intention: 'no'
    post :complete, params: {signature: "My Name"}
    assert_response :forbidden

    # intend to teach unit 6, but has not confirmed school
    application.update!(unit_6_intention: 'yesSpring2020')
    post :complete, params: {signature: "My Name"}
    assert_response :forbidden

    # has confirmed school, but already has a code
    application.update!(school_id: @school.id, circuit_playground_discount_code_id: 123)
    post :complete, params: {signature: "My Name"}
    assert_response :forbidden
  end

  test "complete: returns a new code" do
    DCDO.stubs(:get).with('currently_distributing_discount_codes', false).returns(true)
    sign_in @teacher

    create :circuit_playground_discount_application,
      user: @teacher,
      school: @school,
      unit_6_intention: 'yesSpring2020',
      full_discount: true
    code = create :circuit_playground_discount_code

    post :complete, params: {signature: "My name"}
    assert_response :success
    expected = {code: code.code, expiration: code.expiration}.to_json
    assert_equal expected, @response.body
  end

  test "complete: works after admin override" do
    DCDO.stubs(:get).with('facilitator_ids_eligible_for_maker_discount', []).returns([])
    DCDO.stubs(:get).with('currently_distributing_discount_codes', false).returns(true)
    sign_in @admin

    post :override, params: {user: @teacher.id, full_discount: true}
    assert_response :success
    sign_out @admin

    create :circuit_playground_discount_code

    sign_in @teacher
    post :complete, params: {signature: "My name"}
    assert_response :success
  end

  test "application_status: fails if not admin" do
    sign_in @teacher

    get :application_status, params: {user: @teacher.id}
    assert_response :forbidden
  end

  test "application_status: works for user without in progress application" do
    sign_in @admin

    get :application_status, params: {user: @teacher.id}
    assert_response :success
    refute_nil JSON.parse(@response.body)['application']
    # actual contents tested in CircuitPlaygroundDiscountApplication tests
  end

  test "application_status: works for user with in progress application" do
    sign_in @admin

    create :circuit_playground_discount_application,
      user_id: @teacher.id,
      unit_6_intention: 'yesSpring2020',
      school_id: @school.id,
      full_discount: true

    get :application_status, params: {user: @teacher.id}
    assert_response :success
    refute_nil JSON.parse(@response.body)['application']
    # actual contents tested in CircuitPlaygroundDiscountApplication tests
  end

  test "override: fails if not admin" do
    sign_in @teacher

    post :override, params: {user: @teacher.id, full_discount: true}
    assert_response :forbidden
  end

  test "override: can override discount for a user that has not started an application" do
    sign_in @admin

    assert_equal 0, CircuitPlaygroundDiscountApplication.where(user_id: @teacher.id).length

    post :override, params: {user: @teacher.id, full_discount: true}
    assert_response :success
    expected = {
      "application" => {
        "is_pd_eligible" => false,
        "is_progress_eligible" => false,
        "user_school" => {
          "id" => nil,
          "name" => nil,
          "high_needs" => nil,
        },
        "application_school" => {
          "id" => nil,
          "name" => nil,
          "high_needs" => nil,
        },
        "unit_6_intention" => nil,
        "full_discount" => true,
        "admin_set_status" => true,
        "discount_code" => nil,
      }
    }
    assert_equal expected, JSON.parse(@response.body)

    assert_equal 1, CircuitPlaygroundDiscountApplication.where(user_id: @teacher.id).length
  end

  test "override: can update an existing application that does not yet have a code" do
    sign_in @admin

    # Application in which user has answered question about unit6 intentions, but
    # has not yet confirmed school
    create :circuit_playground_discount_application,
      user_id: @teacher.id,
      unit_6_intention: 'yesSpring2020'
    post :override, params: {user: @teacher.id, full_discount: true}
    assert_response :success
    expected = {
      "application" => {
        "is_pd_eligible" => false,
        "is_progress_eligible" => false,
        "user_school" => {
          "id" => nil,
          "name" => nil,
          "high_needs" => nil,
        },
        "application_school" => {
          "id" => nil,
          "name" => nil,
          "high_needs" => nil,
        },
        "unit_6_intention" => "yesSpring2020",
        "full_discount" => true,
        "admin_set_status" => true,
        "discount_code" => nil,
      }
    }
    assert_equal expected, JSON.parse(@response.body)

    assert_equal 1, CircuitPlaygroundDiscountApplication.where(user_id: @teacher.id).length
  end

  private

  def ensure_script(script_name, version_year='2000', is_stable=true)
    Unit.find_by_name(script_name) ||
      create(:script, name: script_name, family_name: 'devices', version_year: version_year, published_state: is_stable ? Curriculum::SharedCourseConstants::PUBLISHED_STATE.stable : Curriculum::SharedCourseConstants::PUBLISHED_STATE.preview).tap do |script|
        lesson_group = create :lesson_group, script: script
        lesson = create :lesson, script: script, lesson_group: lesson_group
        create :script_level, script: script, lesson: lesson
      end
  end
end
