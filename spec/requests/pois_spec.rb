require 'rails_helper'

RSpec.describe 'POIs API', type: :request do
  describe 'GET /pois' do
    it 'returns all POIs' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)
      beach = Category.create!(name: 'Beach')

      poi = Poi.create!(
        name: 'Praia da Ursa',
        description: 'A beautiful beach',
        location_point: factory.point(-9.4733, 38.7951)
      )
      poi.categories << beach

      get '/pois'

      expect(response).to have_http_status(:ok)

      pois = JSON.parse(response.body)

      expect(pois.length).to eq(1)
      expect(pois.first['name']).to eq('Praia da Ursa')
      expect(pois.first['description']).to eq('A beautiful beach')
      expect(pois.first['categories'].first['name']).to eq('Beach')
    end

    it 'filters POIs by name' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)

      Poi.create!(
        name: 'Praia da Ursa',
        description: 'A beautiful beach',
        location_point: factory.point(-9.4733, 38.7951)
      )

      Poi.create!(
        name: 'Lisbon Museum',
        description: 'A museum',
        location_point: factory.point(-9.1393, 38.7223)
      )

      get '/pois', params: { name: 'Praia da Ursa' }

      expect(response).to have_http_status(:ok)

      pois = JSON.parse(response.body)

      expect(pois.length).to eq(1)
      expect(pois.first['name']).to eq('Praia da Ursa')
    end

    it 'filters POIs by category' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)

      beach = Category.create!(name: 'Beach')
      museum = Category.create!(name: 'Museum')

      beach_poi = Poi.create!(
        name: 'Praia da Ursa',
        description: 'A beautiful beach',
        location_point: factory.point(-9.4733, 38.7951)
      )
      beach_poi.categories << beach

      museum_poi = Poi.create!(
        name: 'Lisbon Museum',
        description: 'A museum',
        location_point: factory.point(-9.1393, 38.7223)
      )
      museum_poi.categories << museum

      get '/pois', params: { category: beach.id }

      expect(response).to have_http_status(:ok)

      pois = JSON.parse(response.body)

      expect(pois.length).to eq(1)
      expect(pois.first['name']).to eq('Praia da Ursa')
    end
  end

  describe 'GET /pois/:id' do
    it 'returns the requested POI' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)

      poi = Poi.create!(
        name: 'Praia da Ursa',
        description: 'A beautiful beach',
        location_point: factory.point(-9.4733, 38.7951)
      )

      get "/pois/#{poi.id}"

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)

      expect(body['id']).to eq(poi.id)
      expect(body['name']).to eq('Praia da Ursa')
      expect(body['description']).to eq('A beautiful beach')
    end

    it 'returns 404 when the POI does not exist' do
      get '/pois/999999'

      expect(response).to have_http_status(:not_found)
    end
  end
end
