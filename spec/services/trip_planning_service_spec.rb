# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TripPlanningService do
  describe '.plan' do
    let(:factory) { RGeo::Geographic.spherical_factory(srid: 4326) }

    let(:origin) do
      Location.create!(
        name: 'Lisboa',
        region: 'Lisboa',
        location_point: factory.point(-9.1393, 38.7223)
      )
    end

    let(:destination) do
      Location.create!(
        name: 'Porto',
        region: 'Porto',
        location_point: factory.point(-8.6291, 41.1579)
      )
    end

    before do
      allow(RoutingService).to receive(:route) do |origin:, destination:|
        {
          'type' => 'LineString',
          'coordinates' => [
            [origin.location_point.x, origin.location_point.y],
            [destination.location_point.x, destination.location_point.y]
          ]
        }
      end
    end

    it 'selects POIs within the route threshold' do
      poi = Poi.create!(
        name: 'Along Route',
        description: 'Near the route',
        location_point: factory.point(-8.9, 39.8)
      )

      result = TripPlanningService.plan(
        origin: origin,
        destination: destination,
        number_of_pois: 1
      )

      expect(result).to include(poi)
    end

    it 'excludes POIs outside the route threshold' do
      poi = Poi.create!(
        name: 'Off Route',
        description: 'Far from the route',
        location_point: factory.point(-3.0, 45.0)
      )

      result = TripPlanningService.plan(
        origin: origin,
        destination: destination,
        number_of_pois: 1
      )

      expect(result).not_to include(poi)
    end

    it 'orders POIs by their position along the route' do
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

      result = TripPlanningService.plan(
        origin: origin,
        destination: destination,
        number_of_pois: 2
      )

      expect(result).to eq([first_poi, second_poi])
    end

    it 'spreads selected POIs across the route' do
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

      result = TripPlanningService.plan(
        origin: origin,
        destination: destination,
        number_of_pois: 2
      )

      expect(result).to eq([first_poi, last_poi])
      expect(result).not_to include(middle_poi)
    end

    it 'applies the category filter before selecting POIs' do
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

      result = TripPlanningService.plan(
        origin: origin,
        destination: destination,
        number_of_pois: 2,
        categories: [beach]
      )

      expect(result).to contain_exactly(first_beach, second_beach)
      expect(result).not_to include(museum_poi)
    end

    it 'returns POIs matching any of the selected categories' do
      beach = Category.create!(name: 'Beach')
      view = Category.create!(name: 'View')
      museum = Category.create!(name: 'Museum')

      beach_poi = Poi.create!(
        name: 'Beach',
        description: 'Beach',
        location_point: factory.point(-9.0, 39.5)
      )
      beach_poi.categories << beach

      view_poi = Poi.create!(
        name: 'Viewpoint',
        description: 'Viewpoint',
        location_point: factory.point(-8.9, 39.8)
      )
      view_poi.categories << view

      museum_poi = Poi.create!(
        name: 'Museum',
        description: 'Museum',
        location_point: factory.point(-8.8, 40.3)
      )
      museum_poi.categories << museum

      result = TripPlanningService.plan(
        origin: origin,
        destination: destination,
        number_of_pois: 3,
        categories: [beach, view]
      )

      expect(result).to contain_exactly(beach_poi, view_poi)
      expect(result).not_to include(museum_poi)
    end

    it 'does not return a POI more than once when it matches multiple categories' do
      beach = Category.create!(name: 'Beach')
      view = Category.create!(name: 'View')

      poi = Poi.create!(
        name: 'Beach View',
        description: 'Beach with a view',
        location_point: factory.point(-9.0, 39.5)
      )
      poi.categories << [beach, view]

      result = TripPlanningService.plan(
        origin: origin,
        destination: destination,
        number_of_pois: 2,
        categories: [beach, view]
      )

      expect(result).to eq([poi])
    end
  end

  describe '.route_for' do
    let(:factory) { RGeo::Geographic.spherical_factory(srid: 4326) }

    let(:origin) do
      Location.new(
        name: 'Lisboa',
        region: 'Lisboa',
        location_point: factory.point(-9.1393, 38.7223)
      )
    end

    let(:destination) do
      Location.new(
        name: 'Porto',
        region: 'Porto',
        location_point: factory.point(-8.6291, 41.1579)
      )
    end

    it 'returns the route from RoutingService when routing succeeds' do
      route = {
        'type' => 'LineString',
        'coordinates' => [
          [-9.1393, 38.7223],
          [-9.0, 39.5],
          [-8.8, 40.3],
          [-8.6291, 41.1579]
        ]
      }

      allow(RoutingService)
        .to receive(:route)
        .with(origin: origin, destination: destination)
        .and_return(route)

      result = described_class.send(
        :route_for,
        origin,
        destination
      )

      expect(result).to eq(route)
    end

    it 'falls back to a straight-line route when routing fails' do
      allow(RoutingService)
        .to receive(:route)
        .with(origin: origin, destination: destination)
        .and_raise(
          RoutingService::RoutingError,
          'No driving route could be found.'
        )

      result = described_class.send(
        :route_for,
        origin,
        destination
      )

      expect(result).to eq(
        'type' => 'LineString',
        'coordinates' => [
          [-9.1393, 38.7223],
          [-8.6291, 41.1579]
        ]
      )
    end
  end

  describe '.select_pois' do
    def poi_at(position)
      Struct.new(:route_position).new(position)
    end

    it 'selects the POI closest to the centre of each route section' do
      pois = [
        poi_at(0.05),
        poi_at(0.20),
        poi_at(0.45),
        poi_at(0.55),
        poi_at(0.80),
        poi_at(0.95)
      ]

      result = TripPlanningService.send(:select_pois, pois, 3)

      expect(result.map(&:route_position)).to eq(
        [0.20, 0.45, 0.80]
      )
    end

    it 'uses unused POIs to fill empty route sections' do
      pois = [
        poi_at(0.05),
        poi_at(0.10),
        poi_at(0.90)
      ]

      result = TripPlanningService.send(:select_pois, pois, 3)

      expect(result.map(&:route_position)).to eq(
        [0.05, 0.10, 0.90]
      )
    end

    it 'returns all POIs when fewer are available than requested' do
      pois = [
        poi_at(0.2),
        poi_at(0.8)
      ]

      result = TripPlanningService.send(:select_pois, pois, 5)

      expect(result).to eq(pois)
    end

    it 'selects the POI closest to the middle of the route when one POI is requested' do
      first = poi_at(0.1)
      middle = poi_at(0.45)

      result = TripPlanningService.send(
        :select_pois,
        [first, middle],
        1
      )

      expect(result).to eq([middle])
    end
  end
end
