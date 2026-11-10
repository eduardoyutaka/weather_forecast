require "test_helper"

class ForecastsControllerTest < ActionDispatch::IntegrationTest
  test "renders the forecast in Fahrenheit inside the turbo frame" do
    stub_open_weather_map

    get address_forecast_path("90210")

    assert_response :success
    assert_select "turbo-frame#forecast" do
      assert_select ".temperature", "69°F"
      assert_select "p", /High 72°F · Low 65°F/
      assert_select "p", "Clear sky"
    end
  end

  test "flags the first response as live and later ones as cached" do
    stub = stub_open_weather_map

    with_memory_cache do
      get address_forecast_path("90210")
      assert_select ".badge", "Live"

      get address_forecast_path("90210")
      assert_select ".badge", "Cached"

      travel 31.minutes do
        get address_forecast_path("90210")
        assert_select ".badge", "Live"
      end
    end

    assert_requested stub, times: 2
  end

  test "upstream failures render a friendly message inside the frame with 503" do
    [
      -> { stub_open_weather_map(status: 500, body: "boom") },
      -> { stub_request(:get, ApiStubs::OPEN_WEATHER_MAP_URL).to_timeout },
      -> { stub_open_weather_map(body: "{not json") }
    ].each do |stub_failure|
      stub_failure.call

      get address_forecast_path("90210")

      assert_response :service_unavailable
      assert_select "turbo-frame#forecast .alert", /temporarily unavailable/
    end
  end

  test "forwards the upstream Retry-After hint when rate limited" do
    stub_open_weather_map(status: 429, body: "{}", headers: { "Retry-After" => "120" })

    get address_forecast_path("90210")

    assert_response :service_unavailable
    assert_equal "120", response.headers["Retry-After"]
  end

  test "unknown address returns 404" do
    get address_forecast_path("99999")

    assert_response :not_found
  end
end
