require "test_helper"

class ForecastServiceTest < ActiveSupport::TestCase
  # Counts calls and can be told to fail, so the tests assert on behaviour
  # (how often the upstream is hit) rather than on HTTP details.
  class FakeWeatherClient
    attr_reader :calls
    attr_accessor :error, :on_call

    def initialize
      @calls = 0
    end

    def current(latitude:, longitude:)
      @calls += 1
      on_call&.call
      raise error if error

      Forecast.new(temperature: 70.0, temperature_min: 65.0, temperature_max: 75.0,
                   description: "clear sky", observed_at: Time.current, fetched_at: Time.current)
    end
  end

  setup do
    @client = FakeWeatherClient.new
    @cache = ActiveSupport::Cache::MemoryStore.new
    @service = ForecastService.new(weather_client: @client, cache: @cache)
    @address = addresses(:beverly_hills)
  end

  test "fetches from the API on a cache miss" do
    result = @service.call(@address)

    assert_not result.cached?
    assert_equal 70.0, result.forecast.temperature
    assert_equal 1, @client.calls
  end

  test "serves subsequent requests for the same ZIP from cache" do
    first = @service.call(@address)
    second = @service.call(@address)

    assert second.cached?
    assert_equal first.forecast, second.forecast
    assert_equal 1, @client.calls
  end

  test "caches per ZIP code rather than per record" do
    @service.call(@address)

    assert @cache.exist?(ForecastService.cache_key("90210"))
    assert ForecastService.new(weather_client: @client, cache: @cache).call(Address.new(postal_code: "90210")).cached?
  end

  test "keeps entries for 30 minutes and refreshes afterwards" do
    @service.call(@address)

    travel 29.minutes
    assert @service.call(@address).cached?

    travel 2.minutes
    assert_not @service.call(@address).cached?
    assert_equal 2, @client.calls
  end

  test "does not cache failures" do
    @client.error = ApiClient::UnavailableError.new("down")
    assert_raises(ApiClient::UnavailableError) { @service.call(@address) }
    assert_not @cache.exist?(ForecastService.cache_key(@address.postal_code))

    @client.error = nil
    assert_not @service.call(@address).cached?
    assert_equal 2, @client.calls
  end

  test "keeps serving the stale entry to concurrent readers while one refreshes" do
    @service.call(@address)
    travel ForecastService::CACHE_TTL + 1.second

    # While the first reader after expiry is refreshing (i.e. inside the API
    # call), a second reader arrives. Thanks to race_condition_ttl it should get
    # the stale entry instead of also hitting the API.
    concurrent_result = nil
    @client.on_call = -> {
      @client.on_call = nil
      concurrent_result = ForecastService.new(weather_client: @client, cache: @cache).call(@address)
    }

    refreshed = @service.call(@address)

    assert_not refreshed.cached?
    assert concurrent_result.cached?
    assert_equal 2, @client.calls
  end
end
