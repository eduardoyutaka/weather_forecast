class Address < ApplicationRecord
  validates :city, :state, :country_code, :postal_code, :latitude, :longitude, presence: true
  has_many :weather_data
end
