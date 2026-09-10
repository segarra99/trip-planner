# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Category, type: :model do
  describe 'associations' do
    it 'can be associated with pois' do
      category = Category.create!(name: 'beach')
      poi = Poi.create!(
        name: 'Costa Nova',
        location_point: point
      )

      category.pois << poi

      expect(category.pois).to contain_exactly(poi)
      expect(poi.categories).to contain_exactly(category)
    end
  end

  private

  def point
    RGeo::Geographic.spherical_factory(srid: 4326).point(-8.75, 40.61)
  end
end
