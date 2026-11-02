class CreateWeatherData < ActiveRecord::Migration[8.1]
  def change
    create_table :weather_data do |t|
      t.decimal :temperature
      t.decimal :minimum_temperature
      t.decimal :maximum_temperature

      t.timestamps
    end
  end
end
