class WeatherDatum < ApplicationRecord
  validates :temperature, :minimum_temperature, :maximum_temperature, presence: true
  belongs_to :address
end
