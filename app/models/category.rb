# frozen_string_literal: true

# Represents a category that can be associated with multiple POIs.
class Category < ApplicationRecord
  has_and_belongs_to_many :pois
end
