# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_01_035211) do
  create_table "addresses", force: :cascade do |t|
    t.string "city", null: false
    t.string "state", null: false
    t.string "country_code", null: false
    t.string "postal_code", null: false
    t.decimal "latitude", precision: 7, scale: 4, null: false
    t.decimal "longitude", precision: 7, scale: 4, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["postal_code"], name: "index_addresses_on_postal_code"
  end

  create_table "weather_data", force: :cascade do |t|
    t.decimal "temperature", null: false
    t.decimal "minimum_temperature", null: false
    t.decimal "maximum_temperature", null: false
    t.integer "address_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["address_id"], name: "index_weather_data_on_address_id"
  end
end
