require "test_helper"

class AddressLookupTest < ActiveSupport::TestCase
  setup { @lookup = AddressLookup.new }

  test "returns a stored address without calling the geocoder" do
    assert_equal addresses(:beverly_hills), @lookup.call("90210")
    assert_equal addresses(:beverly_hills), @lookup.call(" 90210-1234 ")

    assert_not_requested :any, ApiStubs::ZIPPOPOTAM_URL
  end

  test "geocodes and persists an unseen postal code" do
    stub_zippopotam("10001")

    address = assert_difference("Address.count", 1) { @lookup.call("10001") }

    assert address.persisted?
    assert_equal [ "New York City", "New York", "US" ], [ address.city, address.state, address.country_code ]
    assert_equal BigDecimal("40.7484"), address.latitude
  end

  test "rejects malformed input before any network call" do
    [ nil, "", "abc", "1234", "../10001", { "x" => "1" } ].each do |input|
      assert_raises(AddressLookup::InvalidPostalCode) { @lookup.call(input) }
    end

    assert_not_requested :any, ApiStubs::ZIPPOPOTAM_URL
  end

  test "propagates geocoder errors without persisting anything" do
    stub_zippopotam("00000", status: 404, body: "{}")

    assert_no_difference("Address.count") do
      assert_raises(ApiClient::NotFoundError) { @lookup.call("00000") }
    end
  end

  test "returns the winner's row when a concurrent request stores the same ZIP first" do
    # Another request inserts 10001 while ours is waiting on the geocoder, so
    # our find_by missed but our INSERT will hit the unique index.
    racing_geocoder = Object.new
    racing_geocoder.define_singleton_method(:locate) do |postal_code|
      attributes = { postal_code:, city: "New York City", state: "New York", country_code: "US", latitude: 40.7484, longitude: -73.9967 }
      Address.create!(attributes)
      attributes
    end

    address = assert_difference("Address.count", 1) { AddressLookup.new(geocoder: racing_geocoder).call("10001") }

    assert_equal Address.find_by!(postal_code: "10001"), address
  end

  test "wraps unusable geocoder data as an invalid upstream response" do
    bad_geocoder = Object.new
    bad_geocoder.define_singleton_method(:locate) { |_| { city: "", state: "X", country_code: "US", latitude: 1, longitude: 1 } }

    assert_raises(ApiClient::InvalidResponseError) { AddressLookup.new(geocoder: bad_geocoder).call("10001") }
  end
end
