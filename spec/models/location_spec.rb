# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Location, type: :model do
  describe '.name_matches' do
    let!(:lisboa) do
      Location.create!(
        name: 'Lisboa',
        region: 'Lisboa',
        location_point: point(-9.1393, 38.7223)
      )
    end

    let!(:porto) do
      Location.create!(
        name: 'Porto',
        region: 'Porto',
        location_point: point(-8.6291, 41.1579)
      )
    end

    it 'matches locations by partial name' do
      expect(Location.name_matches('Lis')).to contain_exactly(lisboa)
    end

    it 'is case insensitive' do
      expect(Location.name_matches('LIS')).to contain_exactly(lisboa)
    end

    it 'returns no results when there is no match' do
      expect(Location.name_matches('Madrid')).to be_empty
    end
  end

  describe '#latitude' do
    it 'returns the latitude from the location point' do
      location = Location.new(
        location_point: point(-9.1393, 38.7223)
      )

      expect(location.latitude).to eq(38.7223)
    end
  end

  describe '#longitude' do
    it 'returns the longitude from the location point' do
      location = Location.new(
        location_point: point(-9.1393, 38.7223)
      )

      expect(location.longitude).to eq(-9.1393)
    end
  end

  private

  def point(longitude, latitude)
    RGeo::Geographic.spherical_factory(srid: 4326).point(
      longitude,
      latitude
    )
  end
end
