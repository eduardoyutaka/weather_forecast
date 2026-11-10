# Resolves a US ZIP code to a persisted Address, calling the geocoder only the
# first time a ZIP is seen.
class AddressLookup
  class InvalidPostalCode < StandardError; end

  def initialize(geocoder: ZippopotamClient.new)
    @geocoder = geocoder
  end

  # Raises InvalidPostalCode for malformed input (before any network call) and
  # lets ApiClient::Error propagate for upstream failures.
  def call(raw_postal_code)
    postal_code = Address.normalize_value_for(:postal_code, raw_postal_code)
    raise InvalidPostalCode, "invalid US ZIP code: #{raw_postal_code.inspect}" unless Address.valid_postal_code?(postal_code)

    Address.find_by(postal_code:) || create_from_geocoder(postal_code)
  end

  private

  def create_from_geocoder(postal_code)
    attributes = @geocoder.locate(postal_code).merge(postal_code:)

    # Two requests for the same new ZIP can race past the find_by above. The
    # unique index turns the loser's INSERT into a lookup of the winner's row.
    Address.create_or_find_by!(postal_code:) { |address| address.assign_attributes(attributes) }
  rescue ActiveRecord::RecordInvalid => e
    raise ApiClient::InvalidResponseError, "geocoder returned unusable data: #{e.record.errors.full_messages.to_sentence}"
  end
end
