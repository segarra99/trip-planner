require 'swagger_helper'

RSpec.describe 'Trip Planning API', type: :request do
  path '/trip-planning' do
    get 'Plan a trip' do
      tags 'Trip Planning'
      produces 'application/json'

      parameter name: :origin,
                in: :query,
                required: true,
                description: 'Location ID',
                schema: { type: :integer, example: 1 }

      parameter name: :destination,
                in: :query,
                required: true,
                description: 'Location ID',
                schema: { type: :integer, example: 2 }

      parameter name: :number_of_pois,
                in: :query,
                required: true,
                description: 'Number of points of interest',
                schema: {
                  type: :integer,
                  minimum: 1,
                  example: 3
                }

      parameter name: :category,
                in: :query,
                required: false,
                description: 'Filter by category ID',
                schema: { type: :integer, example: 1 }

      parameter name: :page,
                in: :query,
                required: false,
                description: 'Page number',
                schema: { type: :integer, minimum: 1, example: 1 }

      parameter name: :per_page,
                in: :query,
                required: false,
                description: 'Number of POIs per page',
                schema: { type: :integer, minimum: 1, example: 10 }

      response '200', 'POIs returned' do
        schema oneOf: [
          {
            type: :array,
            items: {
              '$ref' => '#/components/schemas/Poi'
            }
          },
          {
            type: :object,
            properties: {
              pois: {
                type: :array,
                items: {
                  '$ref' => '#/components/schemas/Poi'
                }
              },
              pagination: {
                '$ref' => '#/components/schemas/Pagination'
              }
            },
            required: %w[pois pagination]
          }
        ]

        context 'when enough POIs are available' do
          let(:factory) do
            RGeo::Geographic.spherical_factory(srid: 4326)
          end

          let!(:lisboa) do
            Location.create!(
              name: 'Lisboa',
              region: 'Lisboa',
              location_point: factory.point(-9.1393, 38.7223)
            )
          end

          let!(:porto) do
            Location.create!(
              name: 'Porto',
              region: 'Porto',
              location_point: factory.point(-8.6291, 41.1579)
            )
          end

          let!(:first_poi) do
            Poi.create!(
              name: 'First POI',
              description: 'First stop',
              location_point: factory.point(-9.0, 39.5)
            )
          end

          let!(:second_poi) do
            Poi.create!(
              name: 'Second POI',
              description: 'Second stop',
              location_point: factory.point(-8.8, 40.3)
            )
          end

          let!(:third_poi) do
            Poi.create!(
              name: 'Third POI',
              description: 'Third stop',
              location_point: factory.point(-8.7, 40.7)
            )
          end

          let(:origin) { lisboa.id }
          let(:destination) { porto.id }
          let(:number_of_pois) { 2 }

          run_test! do |response|
            pois = JSON.parse(response.body)

            expect(pois.length).to eq(2)
            expect(pois.map { |poi| poi['id'] }).to eq(
              [first_poi.id, third_poi.id]
            )
          end
        end

        context 'when fewer POIs are available' do
          let(:factory) do
            RGeo::Geographic.spherical_factory(srid: 4326)
          end

          let!(:lisboa) do
            Location.create!(
              name: 'Lisboa',
              region: 'Lisboa',
              location_point: factory.point(-9.1393, 38.7223)
            )
          end

          let!(:porto) do
            Location.create!(
              name: 'Porto',
              region: 'Porto',
              location_point: factory.point(-8.6291, 41.1579)
            )
          end

          let!(:only_poi) do
            Poi.create!(
              name: 'Only POI',
              description: 'Only stop',
              location_point: factory.point(-9.0, 39.5)
            )
          end

          let(:origin) { lisboa.id }
          let(:destination) { porto.id }
          let(:number_of_pois) { 3 }

          run_test! do |response|
            pois = JSON.parse(response.body)

            expect(pois.length).to eq(1)
            expect(pois.first['name']).to eq('Only POI')
          end
        end

        context 'when filtering by category' do
          let(:factory) do
            RGeo::Geographic.spherical_factory(srid: 4326)
          end

          let!(:lisboa) do
            Location.create!(
              name: 'Lisboa',
              region: 'Lisboa',
              location_point: factory.point(-9.1393, 38.7223)
            )
          end

          let!(:porto) do
            Location.create!(
              name: 'Porto',
              region: 'Porto',
              location_point: factory.point(-8.6291, 41.1579)
            )
          end

          let!(:beach) { Category.create!(name: 'Beach') }
          let!(:museum) { Category.create!(name: 'Museum') }

          let!(:beach_poi) do
            poi = Poi.create!(
              name: 'Beach POI',
              description: 'A beach',
              location_point: factory.point(-9.0, 39.5)
            )
            poi.categories << beach
            poi
          end

          let!(:museum_poi) do
            poi = Poi.create!(
              name: 'Museum POI',
              description: 'A museum',
              location_point: factory.point(-8.8, 40.3)
            )
            poi.categories << museum
            poi
          end

          let(:origin) { lisboa.id }
          let(:destination) { porto.id }
          let(:number_of_pois) { 2 }
          let(:category) { beach.id }

          run_test! do |response|
            pois = JSON.parse(response.body)

            expect(pois.length).to eq(1)
            expect(pois.first['id']).to eq(beach_poi.id)
          end
        end

        context 'when no POIs match the route' do
          let(:factory) do
            RGeo::Geographic.spherical_factory(srid: 4326)
          end

          let!(:lisboa) do
            Location.create!(
              name: 'Lisboa',
              region: 'Lisboa',
              location_point: factory.point(-9.1393, 38.7223)
            )
          end

          let!(:porto) do
            Location.create!(
              name: 'Porto',
              region: 'Porto',
              location_point: factory.point(-8.6291, 41.1579)
            )
          end

          let!(:far_poi) do
            Poi.create!(
              name: 'Far POI',
              description: 'Not along the route',
              location_point: factory.point(-3.0, 45.0)
            )
          end

          let(:origin) { lisboa.id }
          let(:destination) { porto.id }
          let(:number_of_pois) { 2 }

          run_test! do |response|
            expect(JSON.parse(response.body)).to eq([])
          end
        end

        context 'when no pagination params are provided' do
          let(:factory) do
            RGeo::Geographic.spherical_factory(srid: 4326)
          end

          let!(:lisboa) do
            Location.create!(
              name: 'Lisboa',
              region: 'Lisboa',
              location_point: factory.point(-9.1393, 38.7223)
            )
          end

          let!(:porto) do
            Location.create!(
              name: 'Porto',
              region: 'Porto',
              location_point: factory.point(-8.6291, 41.1579)
            )
          end

          let!(:first_poi) do
            Poi.create!(
              name: 'First POI',
              description: 'First stop',
              location_point: factory.point(-9.0, 39.5)
            )
          end

          let!(:second_poi) do
            Poi.create!(
              name: 'Second POI',
              description: 'Second stop',
              location_point: factory.point(-8.8, 40.3)
            )
          end

          let!(:third_poi) do
            Poi.create!(
              name: 'Third POI',
              description: 'Third stop',
              location_point: factory.point(-8.7, 40.7)
            )
          end

          let(:origin) { lisboa.id }
          let(:destination) { porto.id }
          let(:number_of_pois) { 5 }

          run_test! do |response|
            body = JSON.parse(response.body)

            expect(body).to be_an(Array)
            expect(body.length).to eq(3)
            expect(body.map { |poi| poi['id'] }).to eq(
              [first_poi.id, second_poi.id, third_poi.id]
            )
          end
        end

        context 'when page and per_page are provided' do
          let(:factory) do
            RGeo::Geographic.spherical_factory(srid: 4326)
          end

          let!(:lisboa) do
            Location.create!(
              name: 'Lisboa',
              region: 'Lisboa',
              location_point: factory.point(-9.1393, 38.7223)
            )
          end

          let!(:porto) do
            Location.create!(
              name: 'Porto',
              region: 'Porto',
              location_point: factory.point(-8.6291, 41.1579)
            )
          end

          let!(:first_poi) do
            Poi.create!(
              name: 'First POI',
              description: 'First stop',
              location_point: factory.point(-9.0, 39.5)
            )
          end

          let!(:second_poi) do
            Poi.create!(
              name: 'Second POI',
              description: 'Second stop',
              location_point: factory.point(-8.8, 40.3)
            )
          end

          let!(:third_poi) do
            Poi.create!(
              name: 'Third POI',
              description: 'Third stop',
              location_point: factory.point(-8.7, 40.7)
            )
          end

          let(:origin) { lisboa.id }
          let(:destination) { porto.id }
          let(:number_of_pois) { 5 }
          let(:page) { 2 }
          let(:per_page) { 2 }

          run_test! do |response|
            body = JSON.parse(response.body)

            expect(body['pois'].map { |poi| poi['id'] }).to eq(
              [third_poi.id]
            )

            expect(body['pagination']).to eq(
              'page' => 2,
              'per_page' => 2,
              'total' => 3,
              'total_pages' => 2
            )
          end
        end

        context 'when only page is provided' do
          let(:factory) do
            RGeo::Geographic.spherical_factory(srid: 4326)
          end

          let!(:lisboa) do
            Location.create!(
              name: 'Lisboa',
              region: 'Lisboa',
              location_point: factory.point(-9.1393, 38.7223)
            )
          end

          let!(:porto) do
            Location.create!(
              name: 'Porto',
              region: 'Porto',
              location_point: factory.point(-8.6291, 41.1579)
            )
          end

          let!(:first_poi) do
            Poi.create!(
              name: 'First POI',
              description: 'First stop',
              location_point: factory.point(-9.0, 39.5)
            )
          end

          let!(:second_poi) do
            Poi.create!(
              name: 'Second POI',
              description: 'Second stop',
              location_point: factory.point(-8.8, 40.3)
            )
          end

          let!(:third_poi) do
            Poi.create!(
              name: 'Third POI',
              description: 'Third stop',
              location_point: factory.point(-8.7, 40.7)
            )
          end

          let(:origin) { lisboa.id }
          let(:destination) { porto.id }
          let(:number_of_pois) { 5 }
          let(:page) { 1 }

          run_test! do |response|
            body = JSON.parse(response.body)

            expect(body['pois'].map { |poi| poi['id'] }).to eq(
              [first_poi.id, second_poi.id, third_poi.id]
            )

            expect(body['pagination']).to eq(
              'page' => 1,
              'per_page' => 10,
              'total' => 3,
              'total_pages' => 1
            )
          end
        end

        context 'when only per_page is provided' do
          let(:factory) do
            RGeo::Geographic.spherical_factory(srid: 4326)
          end

          let!(:lisboa) do
            Location.create!(
              name: 'Lisboa',
              region: 'Lisboa',
              location_point: factory.point(-9.1393, 38.7223)
            )
          end

          let!(:porto) do
            Location.create!(
              name: 'Porto',
              region: 'Porto',
              location_point: factory.point(-8.6291, 41.1579)
            )
          end

          let!(:first_poi) do
            Poi.create!(
              name: 'First POI',
              description: 'First stop',
              location_point: factory.point(-9.0, 39.5)
            )
          end

          let!(:second_poi) do
            Poi.create!(
              name: 'Second POI',
              description: 'Second stop',
              location_point: factory.point(-8.8, 40.3)
            )
          end

          let!(:third_poi) do
            Poi.create!(
              name: 'Third POI',
              description: 'Third stop',
              location_point: factory.point(-8.7, 40.7)
            )
          end

          let(:origin) { lisboa.id }
          let(:destination) { porto.id }
          let(:number_of_pois) { 5 }
          let(:per_page) { 2 }

          run_test! do |response|
            body = JSON.parse(response.body)

            expect(body['pois'].map { |poi| poi['id'] }).to eq(
              [first_poi.id, second_poi.id]
            )

            expect(body['pagination']).to eq(
              'page' => 1,
              'per_page' => 2,
              'total' => 3,
              'total_pages' => 2
            )
          end
        end

        context 'when the requested page is beyond the last page' do
          let(:factory) do
            RGeo::Geographic.spherical_factory(srid: 4326)
          end

          let!(:lisboa) do
            Location.create!(
              name: 'Lisboa',
              region: 'Lisboa',
              location_point: factory.point(-9.1393, 38.7223)
            )
          end

          let!(:porto) do
            Location.create!(
              name: 'Porto',
              region: 'Porto',
              location_point: factory.point(-8.6291, 41.1579)
            )
          end

          let!(:first_poi) do
            Poi.create!(
              name: 'First POI',
              description: 'First stop',
              location_point: factory.point(-9.0, 39.5)
            )
          end

          let!(:second_poi) do
            Poi.create!(
              name: 'Second POI',
              description: 'Second stop',
              location_point: factory.point(-8.8, 40.3)
            )
          end

          let!(:third_poi) do
            Poi.create!(
              name: 'Third POI',
              description: 'Third stop',
              location_point: factory.point(-8.7, 40.7)
            )
          end

          let(:origin) { lisboa.id }
          let(:destination) { porto.id }
          let(:number_of_pois) { 5 }
          let(:page) { 3 }
          let(:per_page) { 2 }

          run_test! do |response|
            body = JSON.parse(response.body)

            expect(body['pois']).to eq([])

            expect(body['pagination']).to eq(
              'page' => 3,
              'per_page' => 2,
              'total' => 3,
              'total_pages' => 2
            )
          end
        end
      end

      response '404', 'resource not found' do
        schema '$ref' => '#/components/schemas/Error'

        context 'when origin is not found' do
          let(:origin) { 999_999 }
          let(:destination) { 999_998 }
          let(:number_of_pois) { 2 }

          run_test!
        end

        context 'when destination is not found' do
          let(:factory) do
            RGeo::Geographic.spherical_factory(srid: 4326)
          end

          let!(:origin_location) do
            Location.create!(
              name: 'Lisboa',
              region: 'Lisboa',
              location_point: factory.point(-9.1393, 38.7223)
            )
          end

          let(:origin) { origin_location.id }
          let(:destination) { 999_999 }
          let(:number_of_pois) { 2 }

          run_test!
        end

        context 'when category is not found' do
          let(:factory) do
            RGeo::Geographic.spherical_factory(srid: 4326)
          end

          let!(:origin_location) do
            Location.create!(
              name: 'Lisboa',
              region: 'Lisboa',
              location_point: factory.point(-9.1393, 38.7223)
            )
          end

          let!(:destination_location) do
            Location.create!(
              name: 'Porto',
              region: 'Porto',
              location_point: factory.point(-8.6291, 41.1579)
            )
          end

          let(:origin) { origin_location.id }
          let(:destination) { destination_location.id }
          let(:number_of_pois) { 2 }
          let(:category) { 999_999 }

          run_test!
        end
      end

      response '400', 'invalid request' do
        schema '$ref' => '#/components/schemas/Error'

        context 'when origin is missing' do
          let(:origin) { nil }
          let(:destination) { 1 }
          let(:number_of_pois) { 2 }

          run_test!
        end

        context 'when destination is missing' do
          let(:origin) { 1 }
          let(:destination) { nil }
          let(:number_of_pois) { 2 }

          run_test!
        end

        context 'when number_of_pois is missing' do
          let(:origin) { 1 }
          let(:destination) { 2 }
          let(:number_of_pois) { nil }

          run_test!
        end

        context 'when number_of_pois is not a positive integer' do
          let(:origin) { 1 }
          let(:destination) { 2 }
          let(:number_of_pois) { 0 }

          run_test!
        end
      end
    end
  end
end
