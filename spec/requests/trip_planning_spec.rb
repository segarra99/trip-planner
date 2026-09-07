require 'rails_helper'

RSpec.describe 'Trip Planning API', type: :request do
  describe 'GET /trip-planning' do
    it 'returns the desired number of POIs along the route in order' do
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

      Poi.create!(
        name: 'Second POI',
        description: 'Second stop',
        location_point: factory.point(-8.8, 40.3)
      )

      third_poi = Poi.create!(
        name: 'Third POI',
        description: 'Third stop',
        location_point: factory.point(-8.7, 40.7)
      )

      get '/trip-planning', params: {
        origin: origin.id,
        destination: destination.id,
        number_of_pois: 2
      }

      expect(response).to have_http_status(:ok)

      pois = JSON.parse(response.body)

      expect(pois.length).to eq(2)
      expect(pois.map { |poi| poi['id'] }).to eq([
                                                   first_poi.id,
                                                   third_poi.id
                                                 ])
    end

    it 'returns fewer POIs when fewer are available along the route' do
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
        name: 'Only POI',
        description: 'Only stop',
        location_point: factory.point(-9.0, 39.5)
      )

      get '/trip-planning', params: {
        origin: origin.id,
        destination: destination.id,
        number_of_pois: 3
      }

      expect(response).to have_http_status(:ok)

      pois = JSON.parse(response.body)

      expect(pois.length).to eq(1)
      expect(pois.first['id']).to eq(poi.id)
    end

    it 'filters POIs by category' do
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

      beach_poi = Poi.create!(
        name: 'Beach POI',
        description: 'A beach',
        location_point: factory.point(-9.0, 39.5)
      )
      beach_poi.categories << beach

      museum_poi = Poi.create!(
        name: 'Museum POI',
        description: 'A museum',
        location_point: factory.point(-8.8, 40.3)
      )
      museum_poi.categories << museum

      get '/trip-planning', params: {
        origin: origin.id,
        destination: destination.id,
        number_of_pois: 2,
        category: beach.id
      }

      expect(response).to have_http_status(:ok)

      pois = JSON.parse(response.body)

      expect(pois.length).to eq(1)
      expect(pois.first['id']).to eq(beach_poi.id)
    end

    it 'returns an empty array when no POIs match the route' do
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

      Poi.create!(
        name: 'Far POI',
        description: 'Not along the route',
        location_point: factory.point(-3.0, 45.0)
      )

      get '/trip-planning', params: {
        origin: origin.id,
        destination: destination.id,
        number_of_pois: 2
      }

      expect(response).to have_http_status(:ok)

      expect(JSON.parse(response.body)).to eq([])
    end

    it 'returns 404 when the origin does not exist' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)

      destination = Location.create!(
        name: 'Porto',
        region: 'Porto',
        location_point: factory.point(-8.6291, 41.1579)
      )

      get '/trip-planning', params: {
        origin: 999_999,
        destination: destination.id,
        number_of_pois: 2
      }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 when the destination does not exist' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)

      origin = Location.create!(
        name: 'Lisboa',
        region: 'Lisboa',
        location_point: factory.point(-9.1393, 38.7223)
      )

      get '/trip-planning', params: {
        origin: origin.id,
        destination: 999_999,
        number_of_pois: 2
      }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 when the category does not exist' do
      get '/trip-planning', params: {
        origin: 1,
        destination: 2,
        number_of_pois: 2,
        category: 999_999
      }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 400 when origin is missing' do
      get '/trip-planning', params: {
        destination: 1,
        number_of_pois: 2
      }

      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 400 when destination is missing' do
      get '/trip-planning', params: {
        origin: 1,
        number_of_pois: 2
      }

      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 400 when number_of_pois is missing' do
      get '/trip-planning', params: {
        origin: 1,
        destination: 2
      }

      expect(response).to have_http_status(:bad_request)
    end

    it 'returns 400 when number_of_pois is not a positive integer' do
      get '/trip-planning', params: {
        origin: 1,
        destination: 2,
        number_of_pois: 0
      }

      expect(response).to have_http_status(:bad_request)
    end
  end
end
