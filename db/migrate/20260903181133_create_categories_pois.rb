# Creates the join table connecting categories to points of interest.
# A unique index prevents the same category/POI relationship from being inserted more than once.
class CreateCategoriesPois < ActiveRecord::Migration[8.1]
  def change
    create_table :categories_pois, id: false do |t|
      t.references :category, null: false, foreign_key: true
      t.references :poi, null: false, foreign_key: true
    end

    add_index :categories_pois, %i[category_id poi_id], unique: true
  end
end
