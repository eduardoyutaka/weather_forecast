require "test_helper"

class ZippopotamClientTest < ActiveSupport::TestCase
  setup { @client = ZippopotamClient.new }

  test "maps a successful response to address attributes" do
    stub_zippopotam("10001")

    attributes = @client.locate("10001")

    assert_equal({
      postal_code: "10001",
      country_code: "US",
      city: "New York City",
      state: "New York",
      latitude: BigDecimal("40.7484"),
      longitude: BigDecimal("-73.9967")
    }, attributes)
  end

  test "rejects anything that isn't a 5-digit ZIP before making a request" do
    [ nil, "", "1234", "10001-1234", "../us/10001", "10001/../../", "abcde" ].each do |postal_code|
      assert_raises(ArgumentError, "expected #{postal_code.inspect} to be rejected") { @client.locate(postal_code) }
    end

    assert_not_requested :any, ApiStubs::ZIPPOPOTAM_URL
  end

  test "raises NotFoundError for unknown ZIP codes" do
    stub_zippopotam("00000", status: 404, body: "{}")

    assert_raises(ApiClient::NotFoundError) { @client.locate("00000") }
  end

  test "raises RateLimitedError with the Retry-After value on 429" do
    stub_request(:get, ApiStubs::ZIPPOPOTAM_URL).to_return(status: 429, headers: { "Retry-After" => "30" })

    error = assert_raises(ApiClient::RateLimitedError) { @client.locate("10001") }
    assert_equal 30, error.retry_after
  end

  test "raises UnavailableError on server errors" do
    [ 500, 502, 503 ].each do |status|
      stub_zippopotam("10001", status:, body: "<html>oops</html>")

      assert_raises(ApiClient::UnavailableError) { @client.locate("10001") }
    end
  end

  test "raises UnavailableError on timeouts and connection failures" do
    stub_request(:get, ApiStubs::ZIPPOPOTAM_URL).to_timeout
    assert_raises(ApiClient::UnavailableError) { @client.locate("10001") }

    stub_request(:get, ApiStubs::ZIPPOPOTAM_URL).to_raise(Errno::ECONNREFUSED)
    assert_raises(ApiClient::UnavailableError) { @client.locate("10001") }

    stub_request(:get, ApiStubs::ZIPPOPOTAM_URL).to_raise(SocketError.new("getaddrinfo failed"))
    assert_raises(ApiClient::UnavailableError) { @client.locate("10001") }
  end

  test "raises InvalidResponseError on malformed JSON" do
    stub_zippopotam("10001", body: "{not json")

    assert_raises(ApiClient::InvalidResponseError) { @client.locate("10001") }
  end

  test "raises InvalidResponseError when expected fields are missing" do
    [
      {},
      { "post code" => "10001", "country abbreviation" => "US", "places" => [] },
      { "post code" => "10001", "country abbreviation" => "US", "places" => [ { "place name" => "X" } ] },
      { "post code" => "10001", "country abbreviation" => "US",
        "places" => [ { "place name" => "X", "state" => "Y", "latitude" => "north", "longitude" => "1" } ] }
    ].each do |payload|
      stub_zippopotam("10001", body: payload.to_json)

      assert_raises(ApiClient::InvalidResponseError, "expected #{payload} to be rejected") { @client.locate("10001") }
    end
  end
end
