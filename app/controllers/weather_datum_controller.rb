require "net/http"

class WeatherDatumController < ApplicationController
  before_action :get_address, only: :current

  def index
  end

  def current
    @address.weather_datum.last.created_at > 30.minutes.ago
    @weather_data = WeatherData.new(temperature: parsed_body["main"]["temp"],
                                    minimum_temperature: parsed_body["main"]["temp_min"],
                                    maximum_temperature: parsed_body["main"]["temp_max"])
    @weather_data.save!
    redirect_to @weather_data 

      uri = URI("https://api.openweathermap.org/data/2.5/weather?lat=#{@address.latitude}&lon=#{@address.longitude}&appid=#{Rails.application.credentials.open_weather_map.api_key}")
      response = Net::HTTP.get_response(uri)
      case response
      when Net::HTTPSuccess
        parsed_body = JSON.parse(response.body)
        render json: parsed_body
      else
      end
  end

  private

  def get_address
    @address = Address.find(params[:address_id])
  end
end
