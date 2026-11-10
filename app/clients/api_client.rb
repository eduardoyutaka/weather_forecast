require "net/http"

# Base class for JSON-over-HTTP integrations.
#
# Centralizes the defensive concerns every third-party call needs: explicit
# connect/read timeouts, mapping of transport failures and HTTP status codes to
# a small error hierarchy, and JSON parsing. Subclasses only describe *what* to
# request and how to map the payload into domain objects.
class ApiClient
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class NotFoundError < Error; end
  class UnavailableError < Error; end
  class InvalidResponseError < Error; end

  class RateLimitedError < UnavailableError
    attr_reader :retry_after

    def initialize(message = nil, retry_after: nil)
      super(message)
      @retry_after = retry_after
    end
  end

  OPEN_TIMEOUT = 2 # seconds to establish the TCP/TLS connection
  READ_TIMEOUT = 5 # seconds to wait for each read from the socket

  NETWORK_ERRORS = [
    Timeout::Error, # superclass of Net::OpenTimeout and Net::ReadTimeout
    SocketError,
    IOError, # includes EOFError
    SystemCallError, # Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH...
    OpenSSL::SSL::SSLError
  ].freeze

  private

  def get_json(uri)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                               open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      http.request(Net::HTTP::Get.new(uri, "Accept" => "application/json"))
    end

    parse(response)
  rescue *NETWORK_ERRORS => e
    # Only the host is logged: the query string may carry credentials.
    raise UnavailableError, "#{service_name} unreachable (#{e.class})"
  end

  def parse(response)
    case response
    when Net::HTTPSuccess
      JSON.parse(response.body)
    when Net::HTTPUnauthorized, Net::HTTPForbidden
      raise ConfigurationError, "#{service_name} rejected our credentials (#{response.code})"
    when Net::HTTPNotFound
      raise NotFoundError, "#{service_name} returned 404"
    when Net::HTTPTooManyRequests
      raise RateLimitedError.new("#{service_name} rate limit exceeded", retry_after: response["Retry-After"]&.to_i)
    when Net::HTTPServerError
      raise UnavailableError, "#{service_name} returned #{response.code}"
    else
      raise InvalidResponseError, "#{service_name} returned unexpected status #{response.code}"
    end
  rescue JSON::ParserError
    raise InvalidResponseError, "#{service_name} returned malformed JSON"
  end

  # Wraps payload mapping so that a missing or mistyped field surfaces as an
  # InvalidResponseError instead of a NoMethodError deep inside a view.
  def map_payload
    yield
  rescue KeyError, TypeError, NoMethodError, ArgumentError => e
    raise InvalidResponseError, "#{service_name} returned an unexpected payload (#{e.class}: #{e.message})"
  end

  def service_name
    self.class.name.delete_suffix("Client")
  end
end
