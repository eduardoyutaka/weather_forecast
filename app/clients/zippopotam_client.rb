# Geocodes US ZIP codes using the free Zippopotam.us API.
# https://api.zippopotam.us/us/10001
class ZippopotamClient < ApiClient
  BASE_URL = "https://api.zippopotam.us/us/".freeze
  POSTAL_CODE_FORMAT = /\A\d{5}\z/

  # Returns the attributes needed to build an Address.
  def locate(postal_code)
    # The ZIP is interpolated into the URL path, so never let anything but
    # five digits through (e.g. "../" would change which endpoint we call).
    raise ArgumentError, "invalid US ZIP code: #{postal_code.inspect}" unless POSTAL_CODE_FORMAT.match?(postal_code.to_s)

    payload = get_json(URI("#{BASE_URL}#{postal_code}"))

    map_payload do
      place = payload.fetch("places").first or raise KeyError, "places is empty"

      {
        postal_code: payload.fetch("post code"),
        country_code: payload.fetch("country abbreviation"),
        city: place.fetch("place name"),
        state: place.fetch("state"),
        latitude: BigDecimal(place.fetch("latitude")),
        longitude: BigDecimal(place.fetch("longitude"))
      }
    end
  end
end
