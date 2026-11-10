require "application_system_test_case"

class ForecastsTest < ApplicationSystemTestCase
  test "searching a ZIP code shows the address and its current weather" do
    stub_zippopotam("10001")
    stub_open_weather_map

    visit root_url
    fill_in "ZIP code", with: "10001"
    click_on "Get forecast"

    assert_selector "h1", text: "New York City, New York 10001"
    within "turbo-frame#forecast" do
      assert_text "69°F"
      assert_text "High 72°F · Low 65°F"
      assert_selector ".badge"
    end
  end

  test "an invalid ZIP code shows an error" do
    visit root_url
    fill_in "ZIP code", with: "abc"
    click_on "Get forecast"

    assert_selector ".alert", text: "Please enter a valid 5-digit US ZIP code."
  end
end
