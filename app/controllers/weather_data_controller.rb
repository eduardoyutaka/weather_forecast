require "net/http"

class WeatherDataController < ApplicationController
  before_action :get_address, only: :current
  before_action :get_weather_datum, only: :show

  def index
  end

  def show
  end

  def current
    @weather_data = current_weather_data
    if @weather_data.present?
      redirect_to @weather_data
    else
      flash[:alert] = "Error on fetching weather data"
    end
  end

  private

  def get_weather_datum
    @weather_datum = WeatherDatum.find(params[:id])
  end

  def get_address
    @address = Address.find(params[:address_id])
  end

  def current_weather_data
    Rails.cache.fetch("#{cache_key}/current", expires_in: 30.seconds) do
      uri = URI("https://api.openweathermap.org/data/2.5/weather?lat=#{@address.latitude}&lon=#{@address.longitude}&appid=#{Rails.application.credentials.open_weather_map.api_key}")
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
