require "test_helper"

class AddressesControllerTest < ActionDispatch::IntegrationTest
  test "root renders the search form" do
    get root_path

    assert_response :success
    assert_select "form[action=?][method=post]", addresses_path
    assert_select "input[name=postal_code]"
  end

  test "searching an unseen ZIP geocodes it and redirects to its page" do
    stub_zippopotam("10001")

    assert_difference("Address.count", 1) { post addresses_path, params: { postal_code: "10001" } }

    assert_redirected_to address_path("10001")
    assert_response :see_other
  end

  test "searching a known ZIP+4 redirects without calling the geocoder" do
    post addresses_path, params: { postal_code: "90210-1234" }

    assert_redirected_to address_path("90210")
    assert_not_requested :any, ApiStubs::ZIPPOPOTAM_URL
  end

  test "malformed input re-renders the form with 422" do
    [ "", "abc", "1234", "../10001" ].each do |postal_code|
      post addresses_path, params: { postal_code: }

      assert_response :unprocessable_content
      assert_select ".alert", /valid 5-digit US ZIP code/
    end

    post addresses_path
    assert_response :unprocessable_content

    post addresses_path, params: { postal_code: { nested: "10001" } }
    assert_response :unprocessable_content
  end

  test "unknown ZIP re-renders the form with 422" do
    stub_zippopotam("00000", status: 404, body: "{}")

    post addresses_path, params: { postal_code: "00000" }

    assert_response :unprocessable_content
    assert_select ".alert", /couldn't find a US location/
  end

  test "geocoder outage re-renders the form with 503 instead of erroring" do
    stub_request(:get, ApiStubs::ZIPPOPOTAM_URL).to_timeout

    post addresses_path, params: { postal_code: "10001" }

    assert_response :service_unavailable
    assert_select ".alert", /temporarily unavailable/
  end

  test "address page lazy-loads the forecast frame" do
    get address_path("90210")

    assert_response :success
    assert_select "h1", "Beverly Hills, California 90210"
    assert_select "turbo-frame#forecast[src=?]", address_forecast_path("90210")
  end

  test "unknown address page returns 404" do
    get address_path("99999")

    assert_response :not_found
  end
end
