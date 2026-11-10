# Returns the current forecast for an Address, served from Rails.cache when a
# fetch for the same ZIP code happened within the last 30 minutes.
class ForecastService
  CACHE_TTL = 30.minutes

  # When an entry expires, the first reader extends the stale entry by this long
  # while it refreshes, so concurrent readers keep getting the old value instead
  # of all hitting the API at once (cache stampede).
  RACE_CONDITION_TTL = 10.seconds

  Result = Data.define(:forecast, :cached) do
    alias_method :cached?, :cached
  end

  # Bump the version whenever Forecast's shape changes so old entries are
  # never deserialized into the new structure.
  def self.cache_key(postal_code)
    "forecast/v1/us/#{postal_code}"
  end

  def initialize(weather_client: OpenWeatherMapClient.new, cache: Rails.cache)
    @weather_client = weather_client
    @cache = cache
  end

  # Errors raised by the client propagate out of the fetch block, so failures
  # are never written to the cache.
  def call(address)
    cached = true

    forecast = @cache.fetch(self.class.cache_key(address.postal_code), expires_in: CACHE_TTL, race_condition_ttl: RACE_CONDITION_TTL) do
      cached = false
      @weather_client.current(latitude: address.latitude, longitude: address.longitude)
    end

    Result.new(forecast:, cached:)
  end
end
