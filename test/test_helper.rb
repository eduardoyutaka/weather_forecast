ENV["RAILS_ENV"] ||= "test"
# Tests must never depend on real secrets (CI has no master key) and all HTTP
# is stubbed, so pin a fake key instead of reading credentials.
ENV["OPENWEATHERMAP_API_KEY"] = "test-api-key"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

# Every outbound HTTP call in the suite must be explicitly stubbed. Localhost
# stays open for the system tests' browser driver and app server.
WebMock.disable_net_connect!(allow_localhost: true)

Dir[File.expand_path("support/**/*.rb", __dir__)].each { |file| require file }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include ApiStubs
  end
end

class ActionDispatch::IntegrationTest
  include CacheHelpers
end
