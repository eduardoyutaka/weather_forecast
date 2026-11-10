# Forecasts are ephemeral (30 minute TTL) and now live in Rails.cache only.
class DropWeatherData < ActiveRecord::Migration[8.1]
  def change
    drop_table :weather_data do |t|
      t.decimal :temperature, null: false
      t.decimal :minimum_temperature, null: false
      t.decimal :maximum_temperature, null: false
      t.belongs_to :address

      t.timestamps
    end
  end
end
