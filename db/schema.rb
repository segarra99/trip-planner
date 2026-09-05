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

ActiveRecord::Schema[8.1].define(version: 2026_09_03_181133) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "fuzzystrmatch"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "postgis"
  enable_extension "tiger.postgis_tiger_geocoder"
  enable_extension "topology.postgis_topology"

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "categories_pois", id: false, force: :cascade do |t|
    t.bigint "category_id", null: false
    t.bigint "poi_id", null: false
    t.index ["category_id", "poi_id"], name: "index_categories_pois_on_category_id_and_poi_id", unique: true
    t.index ["category_id"], name: "index_categories_pois_on_category_id"
    t.index ["poi_id"], name: "index_categories_pois_on_poi_id"
  end

  create_table "locations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.geometry "location_point", limit: {:srid=>4326, :type=>"st_point"}, null: false
    t.string "name", null: false
    t.string "region", null: false
    t.datetime "updated_at", null: false
    t.index ["location_point"], name: "index_locations_on_location_point", using: :gist
    t.index ["name"], name: "index_locations_on_name", unique: true
  end

  create_table "pois", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.geometry "location_point", limit: {:srid=>4326, :type=>"st_point"}, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["location_point"], name: "index_pois_on_location_point", using: :gist
    t.index ["name", "location_point"], name: "index_pois_on_name_and_location_point", unique: true
  end

  add_foreign_key "categories_pois", "categories"
  add_foreign_key "categories_pois", "pois"
end
