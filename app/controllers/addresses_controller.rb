require "net/http"

class AddressesController < ApplicationController
  def search
    @address = Address.find_by(params[:postal_code])
    if @address.present?
        redirect_to @address
    else
      uri = URI("https://api.zippopotam.us/us/#{params[:postal_code]}")
      response = Net::HTTP.get_response(uri)
      case response
      when Net::HTTPSuccess
        parsed_body = JSON.parse(response.body)
        @address = Address.new(
          city: parsed_body["places"][0]["place name"],
          state: parsed_body["places"][0]["state"],
          country_code: parsed_body["country abbreviation"],
          postal_code: parsed_body["post code"],
          latitude: parsed_body["places"][0]["latitude"],
          longitude: parsed_body["places"][0]["longitude"]
        )
        @address.save!
        redirect_to @address
      else
        flash[:alert] = "Address not found"
        redirect_to root_path
      end
    end
  end

  def show
    @address = Address.find(params[:id])
  end
end
