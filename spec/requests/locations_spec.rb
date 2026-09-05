require 'rails_helper'

RSpec.describe 'Locations API', type: :request do
  describe 'GET /locations' do
    it 'returns all locations' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)

      Location.create!(
        name: 'Lisboa',
        region: 'Lisboa',
        location_point: factory.point(-9.1393, 38.7223)
      )

      get '/locations'

      expect(response).to have_http_status(:ok)

      locations = JSON.parse(response.body)

      expect(locations.length).to eq(1)
      expect(locations.first['name']).to eq('Lisboa')
      expect(locations.first['region']).to eq('Lisboa')
    end
  end

  describe 'GET /locations/:id' do
    it 'returns the requested location' do
      factory = RGeo::Geographic.spherical_factory(srid: 4326)

      location = Location.create!(
        name: 'Lisboa',
        region: 'Lisboa',
        location_point: factory.point(-9.1393, 38.7223)
      )

      get "/locations/#{location.id}"

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)

      expect(body['id']).to eq(location.id)
      expect(body['name']).to eq('Lisboa')
      expect(body['region']).to eq('Lisboa')
    end

    it 'returns 404 when the location does not exist' do
      get '/locations/999999'

      expect(response).to have_http_status(:not_found)
    end
  end
end
