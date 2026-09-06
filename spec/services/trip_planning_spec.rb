require 'rails_helper'

RSpec.describe TripPlanning do
  describe '.plan' do
    it 'selects POIs within the route threshold' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)

      origin = Location.create!(
        name: 'Lisboa',
        region: 'Lisboa',
        location_point: factory.point(-9.1393, 38.7223)
      )

      destination = Location.create!(
        name: 'Porto',
        region: 'Porto',
        location_point: factory.point(-8.6291, 41.1579)
      )

      poi = Poi.create!(
        name: 'Along Route',
        description: 'Near the route',
        location_point: factory.point(-8.9, 39.8)
      )

      result = TripPlanning.plan(
        origin: origin,
        destination: destination,
        number_of_pois: 1
      )

      expect(result).to include(poi)
    end

    it 'excludes POIs outside the route threshold' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)

      origin = Location.create!(
        name: 'Lisboa',
        region: 'Lisboa',
        location_point: factory.point(-9.1393, 38.7223)
      )

      destination = Location.create!(
        name: 'Porto',
        region: 'Porto',
        location_point: factory.point(-8.6291, 41.1579)
      )

      poi = Poi.create!(
        name: 'Off Route',
        description: 'Far from the route',
        location_point: factory.point(-3.0, 45.0)
      )

      result = TripPlanning.plan(
        origin: origin,
        destination: destination,
        number_of_pois: 1
      )

      expect(result).not_to include(poi)
    end

    it 'orders POIs by their position along the route' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)

      origin = Location.create!(
        name: 'Lisboa',
        region: 'Lisboa',
        location_point: factory.point(-9.1393, 38.7223)
      )

      destination = Location.create!(
        name: 'Porto',
        region: 'Porto',
        location_point: factory.point(-8.6291, 41.1579)
      )

      first_poi = Poi.create!(
        name: 'First POI',
        description: 'First stop',
        location_point: factory.point(-9.0, 39.5)
      )

      second_poi = Poi.create!(
        name: 'Second POI',
        description: 'Second stop',
        location_point: factory.point(-8.8, 40.3)
      )

      result = TripPlanning.plan(
        origin: origin,
        destination: destination,
        number_of_pois: 2
      )

      expect(result).to eq([first_poi, second_poi])
    end

    it 'spreads selected POIs across the route' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)

      origin = Location.create!(
        name: 'Lisboa',
        region: 'Lisboa',
        location_point: factory.point(-9.1393, 38.7223)
      )

      destination = Location.create!(
        name: 'Porto',
        region: 'Porto',
        location_point: factory.point(-8.6291, 41.1579)
      )

      first_poi = Poi.create!(
        name: 'First POI',
        description: 'First stop',
        location_point: factory.point(-9.0, 39.5)
      )

      middle_poi = Poi.create!(
        name: 'Middle POI',
        description: 'Middle stop',
        location_point: factory.point(-8.9, 39.9)
      )

      last_poi = Poi.create!(
        name: 'Last POI',
        description: 'Last stop',
        location_point: factory.point(-8.8, 40.3)
      )

      result = TripPlanning.plan(
        origin: origin,
        destination: destination,
        number_of_pois: 2
      )

      expect(result).to eq([first_poi, last_poi])
      expect(result).not_to include(middle_poi)
    end

    it 'applies the category filter before selecting POIs' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)

      origin = Location.create!(
        name: 'Lisboa',
        region: 'Lisboa',
        location_point: factory.point(-9.1393, 38.7223)
      )

      destination = Location.create!(
        name: 'Porto',
        region: 'Porto',
        location_point: factory.point(-8.6291, 41.1579)
      )

      beach = Category.create!(name: 'Beach')
      museum = Category.create!(name: 'Museum')

      first_beach = Poi.create!(
        name: 'First Beach',
        description: 'First beach',
        location_point: factory.point(-9.0, 39.5)
      )
      first_beach.categories << beach

      museum_poi = Poi.create!(
        name: 'Museum',
        description: 'Museum',
        location_point: factory.point(-8.9, 39.8)
      )
      museum_poi.categories << museum

      second_beach = Poi.create!(
        name: 'Second Beach',
        description: 'Second beach',
        location_point: factory.point(-8.8, 40.3)
      )
      second_beach.categories << beach

      result = TripPlanning.plan(
        origin: origin,
        destination: destination,
        number_of_pois: 2,
        category: beach
      )

      expect(result).to contain_exactly(first_beach, second_beach)
      expect(result).not_to include(museum_poi)
    end
  end
end
