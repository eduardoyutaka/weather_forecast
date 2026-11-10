# Fetches current conditions from OpenWeatherMap's free "Current weather" API.
# https://openweathermap.org/current
class OpenWeatherMapClient < ApiClient
  BASE_URL = "https://api.openweathermap.org/data/2.5/weather".freeze
  UNITS = "imperial".freeze # US ZIP codes only, so Fahrenheit

  def initialize(api_key: self.class.default_api_key)
    @api_key = api_key
  end

  def self.default_api_key
    ENV["OPENWEATHERMAP_API_KEY"].presence || Rails.application.credentials.dig(:open_weather_map, :api_key)
  end

  def current(latitude:, longitude:)
    raise ConfigurationError, "OpenWeatherMap API key is not configured" if @api_key.blank?

    uri = URI(BASE_URL)
    uri.query = { lat: latitude, lon: longitude, units: UNITS, appid: @api_key }.to_query
    payload = get_json(uri)

    map_payload do
      main = payload.fetch("main")

      Forecast.new(
        temperature: main.fetch("temp").to_f,
        temperature_min: main.fetch("temp_min").to_f,
        temperature_max: main.fetch("temp_max").to_f,
        description: payload.dig("weather", 0, "description"),
        observed_at: Time.zone.at(payload.fetch("dt")),
        fetched_at: Time.current
      )
    end
  end
end
