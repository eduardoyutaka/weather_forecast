# A geocoded US ZIP code. ZIP → coordinates is effectively static, so it's
# persisted once and reused instead of calling the geocoding API on every search.
class Address < ApplicationRecord
  POSTAL_CODE_FORMAT = /\A\d{5}\z/

  # " 10001-1234 " → "10001". Also applied to finders, e.g. find_by(postal_code:).
  normalizes :postal_code, with: ->(value) { value.to_s.strip.sub(/\A(\d{5})-\d{4}\z/, '\1') }

  # Uniqueness is enforced by the unique index, not a `uniqueness:` validation:
  # that validation's SELECT would raise RecordInvalid on a race instead of the
  # RecordNotUnique that create_or_find_by! knows how to recover from.
  validates :postal_code, format: { with: POSTAL_CODE_FORMAT }
  validates :city, :state, :country_code, presence: true
  validates :latitude, numericality: { in: -90..90 }
  validates :longitude, numericality: { in: -180..180 }

  def self.valid_postal_code?(postal_code)
    POSTAL_CODE_FORMAT.match?(postal_code)
  end

  def to_param
    postal_code
  end
end
