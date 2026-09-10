# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Poi, type: :model do
  describe 'associations' do
    it 'can be associated with categories' do
      poi = Poi.create!(
        name: 'Costa Nova',
        location_point: point
      )
      category = Category.create!(name: 'beach')

      poi.categories << category

      expect(poi.categories).to contain_exactly(category)
      expect(category.pois).to contain_exactly(poi)
    end
  end

  describe '.name_matches' do
    let!(:costa_nova) do
      Poi.create!(
        name: 'Costa Nova',
        location_point: point
      )
    end

    let!(:torreira) do
      Poi.create!(
        name: 'Praia da Torreira',
        location_point: point
      )
    end

    it 'matches POIs by partial name' do
      expect(Poi.name_matches('Costa')).to contain_exactly(costa_nova)
    end

    it 'is case insensitive' do
      expect(Poi.name_matches('COSTA')).to contain_exactly(costa_nova)
    end

    it 'returns no results when there is no match' do
      expect(Poi.name_matches('Lisbon')).to be_empty
    end
  end

  describe '.with_category' do
    let!(:beach) { Category.create!(name: 'beach') }
    let!(:culture) { Category.create!(name: 'culture') }

    let!(:costa_nova) do
      Poi.create!(
        name: 'Costa Nova',
        location_point: point
      ).tap do |poi|
        poi.categories << beach
      end
    end

    let!(:museum) do
      Poi.create!(
        name: 'Museum',
        location_point: point
      ).tap do |poi|
        poi.categories << culture
      end
    end

    it 'returns POIs belonging to the category' do
      expect(Poi.with_category(beach.id)).to contain_exactly(costa_nova)
    end

    it 'does not return POIs belonging to another category' do
      expect(Poi.with_category(culture.id)).to contain_exactly(museum)
    end
  end

  describe '.with_categories' do
    let!(:beach) { Category.create!(name: 'beach') }
    let!(:culture) { Category.create!(name: 'culture') }

    let!(:beach_poi) do
      Poi.create!(
        name: 'Beach POI',
        location_point: point
      ).tap do |poi|
        poi.categories << beach
      end
    end

    let!(:culture_poi) do
      Poi.create!(
        name: 'Culture POI',
        location_point: point
      ).tap do |poi|
        poi.categories << culture
      end
    end

    let!(:both_poi) do
      Poi.create!(
        name: 'Beach and Culture POI',
        location_point: point
      ).tap do |poi|
        poi.categories << [beach, culture]
      end
    end

    it 'returns POIs matching any of the given categories' do
      expect(Poi.with_categories([beach.id, culture.id]))
        .to contain_exactly(beach_poi, culture_poi, both_poi)
    end

    it 'returns no results when no categories match' do
      other_category = Category.create!(name: 'history')

      expect(Poi.with_categories([other_category.id])).to be_empty
    end
  end

  describe '#latitude' do
    it 'returns the latitude from the location point' do
      poi = Poi.new(
        location_point: point(-9.1393, 38.7223)
      )

      expect(poi.latitude).to eq(38.7223)
    end
  end

  describe '#longitude' do
    it 'returns the longitude from the location point' do
      poi = Poi.new(
        location_point: point(-9.1393, 38.7223)
      )

      expect(poi.longitude).to eq(-9.1393)
    end
  end

  private

  def point(longitude = -8.75, latitude = 40.61)
    RGeo::Geographic.spherical_factory(srid: 4326).point(
      longitude,
      latitude
    )
  end
end
