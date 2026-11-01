require "net/http"

class WeatherForecastsController < ApplicationController
  def index
  end

  def current
    uri = URI("https://api.openweathermap.org/data/2.5/weather?lat=40.69&lon=-73.99&appid=#{Rails.application.credentials.open_weather_map.api_key}")
    response = Net::HTTP.get_response(uri)
    case response
    when Net::HTTPSuccess
      parsed_body = JSON.parse(response.body)
    else
    end
  end

  private

  def get_address
    @address = Address.find(params[:address_id])
  end
end
