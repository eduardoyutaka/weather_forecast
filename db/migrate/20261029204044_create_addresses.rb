class CreateAddresses < ActiveRecord::Migration[8.1]
  def change
    create_table :addresses do |t|
      t.string :city
      t.string :state
      t.string :country_code
      t.string :post_code
      t.decimal :latitude, precision: 8, scale: 2
      t.decimal :longitude, precision: 8, scale: 2

      t.timestamps
    end
  end
end
