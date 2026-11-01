class Address < ApplicationRecord
  validates :city, :state, :country_code, :postal_code, :latitude, :longitude, presence: true
end
