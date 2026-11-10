# WebMock helpers for the two upstream APIs. Payloads in test/fixtures/files
# are trimmed copies of real responses.
module ApiStubs
  ZIPPOPOTAM_URL = %r{\Ahttps://api\.zippopotam\.us/us/}
  OPEN_WEATHER_MAP_URL = %r{\Ahttps://api\.openweathermap\.org/data/2\.5/weather}

  def stub_zippopotam(postal_code = "10001", status: 200, body: file_fixture("zippopotam_10001.json").read)
    stub_request(:get, "https://api.zippopotam.us/us/#{postal_code}")
      .to_return(status:, body:, headers: { "Content-Type" => "application/json" })
  end

  def stub_open_weather_map(status: 200, body: file_fixture("open_weather_map_current.json").read, headers: {})
    stub_request(:get, OPEN_WEATHER_MAP_URL)
      .to_return(status:, body:, headers: { "Content-Type" => "application/json" }.merge(headers))
  end
end
