require "net/http"

class WeatherDatumController < ApplicationController
  before_action :get_address, only: :current

  def index
  end

  def show
  end

  def current
    Rails.cache.delete("#{cache_key}/current")
    p "DATA", Rails.cache.read("#{cache_key}/current")
    @weather_data = current_weather_data
    if @weather_data.present?
      redirect_to @weather_data
    else
      flash[:alert] = "Error on fetching weather data"
    end
  end

  private

  def get_address
    @address = Address.find(params[:address_id])
  end

  def current_weather_data
    p "#{cache_key}/current"
    Rails.cache.fetch("#{cache_key}/current", expires_in: 30.minutes) do
      p "START"
      uri = URI("https://api.openweathermap.org/data/2.5/weather?lat=#{@address.latitude}&lon=#{@address.longitude}&appid=#{Rails.application.credentials.open_weather_map.api_key}")
      response = Net::HTTP.get_response(uri)
      p "RESPONSE"
      case response
      when Net::HTTPSuccess
        p "SUCCESS"
        parsed_body = JSON.parse(response.body)
        weather_data = @address.weather_data.new(temperature: parsed_body["main"]["temp"],
                                                 minimum_temperature: parsed_body["main"]["temp_min"],
                                                 maximum_temperature: parsed_body["main"]["temp_max"])
        weather_data.save!
        p "DEBUG", weather_data
        weather_data
      else
        p "ERROR"
        Rails.logger.warn("OpenWeatherMap API request failed")
      end
    rescue StandardError => e
      p "RESCUE"
      Rails.logger.error(e.message)
    end
  end

  def cache_key
    "address_#{@address.id}"
  end
end
