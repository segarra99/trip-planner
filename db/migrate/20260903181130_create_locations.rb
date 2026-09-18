# frozen_string_literal: true

# Each location has a name, region, and PostGIS point representing its latitude and longitude.
# Indexes are added to support unique location names and efficient spatial queries.
class CreateLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :locations do |t|
      t.string :name, null: false
      t.string :region, null: false
      t.column :location_point, 'geometry(Point,4326)', null: false
      t.timestamps
    end

    add_index :locations, :name, unique: true
  end
end
