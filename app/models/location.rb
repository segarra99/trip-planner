# Represents a geographic location.
class Location < ApplicationRecord
  scope :name_matches, ->(name) { where('name ILIKE ?', "%#{name}%") }

  def latitude
    location_point&.y
  end

  def longitude
    location_point&.x
  end
end
