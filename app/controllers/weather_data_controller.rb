require "net/http"

class WeatherDataController < ApplicationController
  before_action :get_address, only: :current

  BASE_URI = "https://api.openweathermap.org/data/2.5/weather"

  def index
  end

  def current
    @pulled_from_cache = true
    @weather_datum = current_weather_datum
  end

  private

  def get_address
    @address = Address.find(params[:address_id])
  end

  def current_weather_datum
    Rails.cache.fetch("#{cache_key}/current", expires_in: 30.minutes) do
      @pulled_from_cache = false
      uri = URI(BASE_URI)
      query_params = {
        :lat => @address.latitude,
        :lon => @address.longitude,
        :appid => Rails.application.credentials.open_weather_map.api_key
      }.to_query
      uri.query = query_params
      response = Net::HTTP.get_response(uri)
      case response
      when Net::HTTPSuccess
        parsed_body = JSON.parse(response.body)
        weather_data = @address.weather_data.new(temperature: parsed_body["main"]["temp"],
                                                 minimum_temperature: parsed_body["main"]["temp_min"],
                                                 maximum_temperature: parsed_body["main"]["temp_max"])
        weather_data.save!
        weather_data
      else
        Rails.logger.warn("OpenWeatherMap API request failed")
      end
    rescue StandardError => e
      Rails.logger.error(e.message)
    end
  end

  def cache_key
    "address_#{@address.id}"
  end
end
