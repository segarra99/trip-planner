# Represents a point of interest with one or more categories.
class Poi < ApplicationRecord
  has_and_belongs_to_many :categories

  scope :name_matches, ->(name) { where('pois.name ILIKE ?', "%#{name}%") }
  scope :with_category, ->(category_id) { joins(:categories).where(categories: { id: category_id }) }

  def latitude
    location_point&.y
  end

  def longitude
    location_point&.x
  end
end
