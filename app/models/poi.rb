# Represents a point of interest with one or more categories.
class Poi < ApplicationRecord
  has_and_belongs_to_many :categories
end
