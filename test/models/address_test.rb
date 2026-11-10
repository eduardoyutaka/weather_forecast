require "test_helper"

class AddressTest < ActiveSupport::TestCase
  def build_address(**attributes)
    Address.new(city: "New York City", state: "New York", country_code: "US",
                postal_code: "10001", latitude: 40.7484, longitude: -73.9967, **attributes)
  end

  test "is valid with complete attributes" do
    assert build_address.valid?
  end

  test "normalizes whitespace and ZIP+4 to a 5-digit ZIP" do
    assert_equal "10001", build_address(postal_code: "  10001 ").postal_code
    assert_equal "10001", build_address(postal_code: "10001-1234").postal_code
    assert_equal "10001", Address.normalize_value_for(:postal_code, "10001-1234")
  end

  test "rejects malformed postal codes" do
    [ nil, "", "1234", "123456", "abcde", "10001-12", "../10001" ].each do |postal_code|
      assert_not build_address(postal_code:).valid?, "expected #{postal_code.inspect} to be invalid"
    end
  end

  test "rejects coordinates out of range" do
    assert_not build_address(latitude: 91).valid?
    assert_not build_address(longitude: -181).valid?
  end

  test "enforces one address per postal code at the database level" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      build_address(postal_code: addresses(:beverly_hills).postal_code).save!
    end
  end

  test "uses the postal code in URLs" do
    assert_equal "90210", addresses(:beverly_hills).to_param
  end
end
