require "test_helper"

class OpenWeatherMapClientTest < ActiveSupport::TestCase
  API_KEY = "test-api-key"

  setup { @client = OpenWeatherMapClient.new(api_key: API_KEY) }

  def fetch_current
    @client.current(latitude: BigDecimal("40.7484"), longitude: BigDecimal("-73.9967"))
  end

  test "requests imperial units for the given coordinates and maps the response to a Forecast" do
    stub = stub_request(:get, ApiStubs::OPEN_WEATHER_MAP_URL)
      .with(query: { lat: "40.7484", lon: "-73.9967", units: "imperial", appid: API_KEY })
      .to_return(status: 200, body: file_fixture("open_weather_map_current.json").read)

    forecast = freeze_time { fetch_current }

    assert_requested stub
    assert_equal 68.54, forecast.temperature
    assert_equal 65.12, forecast.temperature_min
    assert_equal 71.6, forecast.temperature_max
    assert_equal "clear sky", forecast.description
    assert_equal Time.zone.at(1762790400), forecast.observed_at
  end

  test "tolerates a missing weather description" do
    payload = JSON.parse(file_fixture("open_weather_map_current.json").read).except("weather")
    stub_open_weather_map(body: payload.to_json)

    assert_nil fetch_current.description
  end

  test "raises ConfigurationError without making a request when no API key is configured" do
    [ nil, "" ].each do |api_key|
      assert_raises(ApiClient::ConfigurationError) do
        OpenWeatherMapClient.new(api_key:).current(latitude: 1, longitude: 1)
      end
    end

    assert_not_requested :any, ApiStubs::OPEN_WEATHER_MAP_URL
  end

  test "raises RateLimitedError on 429" do
    stub_open_weather_map(status: 429, body: '{"cod":429}', headers: { "Retry-After" => "60" })

    error = assert_raises(ApiClient::RateLimitedError) { fetch_current }
    assert_equal 60, error.retry_after
  end

  test "raises UnavailableError on server errors and timeouts" do
    stub_open_weather_map(status: 503, body: "Service Unavailable")
    assert_raises(ApiClient::UnavailableError) { fetch_current }

    stub_request(:get, ApiStubs::OPEN_WEATHER_MAP_URL).to_timeout
    assert_raises(ApiClient::UnavailableError) { fetch_current }

    stub_request(:get, ApiStubs::OPEN_WEATHER_MAP_URL).to_raise(Errno::ECONNRESET)
    assert_raises(ApiClient::UnavailableError) { fetch_current }
  end

  test "raises ConfigurationError when the API key is rejected" do
    stub_open_weather_map(status: 401, body: '{"cod":401,"message":"Invalid API key"}')

    assert_raises(ApiClient::ConfigurationError) { fetch_current }
  end

  test "raises InvalidResponseError on malformed JSON or missing fields" do
    [ "<html>", "{}", { main: { temp: 70 } }.to_json, { main: { temp: 1, temp_min: 1, temp_max: 1 } }.to_json ].each do |body|
      stub_open_weather_map(body:)

      assert_raises(ApiClient::InvalidResponseError, "expected #{body} to be rejected") { fetch_current }
    end
  end

  test "never leaks the API key in error messages" do
    stub_request(:get, ApiStubs::OPEN_WEATHER_MAP_URL).to_timeout

    error = assert_raises(ApiClient::UnavailableError) { fetch_current }
    assert_no_match API_KEY, error.message
  end
end
