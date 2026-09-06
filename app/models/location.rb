# Represents a geographic location.
class Location < ApplicationRecord
  scope :name_matches, ->(name) { where('name ILIKE ?', "%#{name}%") }
end
