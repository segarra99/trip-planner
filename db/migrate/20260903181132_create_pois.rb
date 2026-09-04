# Each POI has a name, description, and PostGIS point representing its location.
# Names and coordinates together must be unique to allow different POIs to share a name.
# A GiST index is also added to support efficient spatial queries.
class CreatePois < ActiveRecord::Migration[8.1]
  def change
    create_table :pois do |t|
      t.string :name, null: false
      t.text :description
      t.column :location_point, 'geometry(Point,4326)', null: false
      t.timestamps
    end

    add_index :pois, %i[name location_point], unique: true
    add_index :pois, :location_point, using: :gist
  end
end
