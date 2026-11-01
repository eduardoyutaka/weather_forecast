class CreateAddresses < ActiveRecord::Migration[8.1]
  def change
    create_table :addresses do |t|
      t.string :city, null: false
      t.string :state, null: false
      t.string :country_code, null: false
      t.string :postal_code, null: false, index: true
      t.decimal :latitude, precision: 8, scale: 2, null: false
      t.decimal :longitude, precision: 8, scale: 2, null: false

      t.timestamps
    end
  end
end
