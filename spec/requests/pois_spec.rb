# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'POIs API', type: :request do
  path '/pois' do
    get 'List POIs' do
      tags 'POIs'
      produces 'application/json'
      description 'Returns all points of interest, optionally filtered by name or category.'

      parameter name: :name,
                in: :query,
                required: false,
                description: 'Filter by point of interest name',
                schema: { type: :string, example: 'Praia da Marinha' }

      parameter name: :category,
                in: :query,
                required: false,
                description: 'Filter by category ID',
                schema: { type: :integer, example: 1 }

      parameter name: :page,
                in: :query,
                required: false,
                description: 'Page number',
                schema: {
                  type: :integer,
                  default: 1,
                  example: 1
                }

      parameter name: :per_page,
                in: :query,
                required: false,
                description: 'Number of POIs per page',
                schema: {
                  type: :integer,
                  default: 10,
                  example: 10
                }

      response '200', 'POIs found' do
        schema type: :object,
               properties: {
                 pois: {
                   type: :array,
                   items: { '$ref' => '#/components/schemas/Poi' }
                 },
                 pagination: {
                   '$ref' => '#/components/schemas/Pagination'
                 }
               },
               required: %w[pois pagination]

        context 'when listing all POIs' do
          let(:factory) { RGeo::Geographic.spherical_factory(srid: 4326) }
          let!(:beach) { Category.create!(name: 'Beach') }
          let!(:museum) { Category.create!(name: 'Museum') }

          let!(:beach_poi) do
            poi = Poi.create!(
              name: 'Praia da Marinha',
              description: 'A beautiful beach',
              location_point: factory.point(-9.4733, 38.7951)
            )
            poi.categories << beach
            poi
          end

          let!(:museum_poi) do
            poi = Poi.create!(
              name: 'Lisbon Museum',
              description: 'A museum',
              location_point: factory.point(-9.1393, 38.7223)
            )
            poi.categories << museum
            poi
          end

          run_test! do |response|
            body = JSON.parse(response.body)
            pois = body['pois']

            expect(pois.length).to eq(2)
            expect(pois.map { |poi| poi['name'] })
              .to contain_exactly('Praia da Marinha', 'Lisbon Museum')
          end
        end

        context 'when no pagination params are provided' do
          let(:factory) { RGeo::Geographic.spherical_factory(srid: 4326) }

          before do
            2.times do |index|
              Poi.create!(
                name: "POI #{index + 1}",
                description: "Description #{index + 1}",
                location_point: factory.point(-9.0 - index, 38.0 + index)
              )
            end
          end

          run_test! do |response|
            body = JSON.parse(response.body)

            expect(body['pois'].length).to eq(2)

            expect(body['pagination']).to eq(
              'page' => 1,
              'per_page' => 10,
              'total' => 2,
              'total_pages' => 1
            )
          end
        end

        context 'when pagination params are provided' do
          let(:factory) { RGeo::Geographic.spherical_factory(srid: 4326) }

          before do
            5.times do |index|
              Poi.create!(
                name: "POI #{index + 1}",
                description: "Description #{index + 1}",
                location_point: factory.point(-9.0 - index, 38.0 + index)
              )
            end
          end

          let(:page) { 2 }
          let(:per_page) { 2 }

          run_test! do |response|
            body = JSON.parse(response.body)

            expect(body['pois'].map { |poi| poi['name'] })
              .to eq(['POI 3', 'POI 4'])

            expect(body['pagination']).to eq(
              'page' => 2,
              'per_page' => 2,
              'total' => 5,
              'total_pages' => 3
            )
          end
        end

        context 'when the requested page is beyond the last page' do
          let(:factory) { RGeo::Geographic.spherical_factory(srid: 4326) }

          before do
            3.times do |index|
              Poi.create!(
                name: "POI #{index + 1}",
                description: "Description #{index + 1}",
                location_point: factory.point(-9.0 - index, 38.0 + index)
              )
            end
          end

          let(:page) { 5 }
          let(:per_page) { 2 }

          run_test! do |response|
            body = JSON.parse(response.body)

            expect(body['pois']).to eq([])

            expect(body['pagination']).to eq(
              'page' => 5,
              'per_page' => 2,
              'total' => 3,
              'total_pages' => 2
            )
          end
        end

        context 'when filtering by name' do
          let(:name) { 'Praia da Marinha' }
          let(:factory) { RGeo::Geographic.spherical_factory(srid: 4326) }

          let!(:beach_poi) do
            Poi.create!(
              name: 'Praia da Marinha',
              description: 'A beautiful beach',
              location_point: factory.point(-9.4733, 38.7951)
            )
          end

          let!(:museum_poi) do
            Poi.create!(
              name: 'Lisbon Museum',
              description: 'A museum',
              location_point: factory.point(-9.1393, 38.7223)
            )
          end

          run_test! do |response|
            body = JSON.parse(response.body)
            pois = body['pois']

            expect(pois.length).to eq(1)
            expect(pois.first['name']).to eq('Praia da Marinha')
          end
        end

        context 'when filtering by category' do
          let(:factory) { RGeo::Geographic.spherical_factory(srid: 4326) }
          let!(:beach) { Category.create!(name: 'Beach') }
          let!(:museum) { Category.create!(name: 'Museum') }

          let!(:beach_poi) do
            poi = Poi.create!(
              name: 'Praia da Marinha',
              description: 'A beautiful beach',
              location_point: factory.point(-9.4733, 38.7951)
            )
            poi.categories << beach
            poi
          end

          let!(:museum_poi) do
            poi = Poi.create!(
              name: 'Lisbon Museum',
              description: 'A museum',
              location_point: factory.point(-9.1393, 38.7223)
            )
            poi.categories << museum
            poi
          end

          let(:category) { beach.id }

          run_test! do |response|
            body = JSON.parse(response.body)
            pois = body['pois']

            expect(pois.length).to eq(1)
            expect(pois.first['name']).to eq('Praia da Marinha')
          end
        end
      end
    end
  end

  path '/pois/{id}' do
    get 'Retrieve a POI' do
      tags 'POIs'
      produces 'application/json'
      description 'Returns a single point of interest by ID.'

      parameter name: :id,
                in: :path,
                required: true,
                schema: { type: :integer, example: 1 }

      response '200', 'POI found' do
        schema '$ref' => '#/components/schemas/Poi'

        let(:factory) { RGeo::Geographic.spherical_factory(srid: 4326) }
        let(:id) do
          Poi.create!(
            name: 'Praia da Marinha',
            description: 'A beautiful beach',
            location_point: factory.point(-9.4733, 38.7951)
          ).id
        end

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body['id']).to eq(id)
          expect(body['name']).to eq('Praia da Marinha')
          expect(body['description']).to eq('A beautiful beach')
        end
      end

      response '404', 'POI not found' do
        schema '$ref' => '#/components/schemas/Error'

        let(:id) { 999_999 }

        run_test!
      end
    end
  end

  path '/pois/nearest' do
    get 'Find nearest POI' do
      tags 'POIs'
      produces 'application/json'
      description 'Returns the point of interest nearest to the supplied coordinates.'

      parameter name: :lat,
                in: :query,
                required: true,
                schema: { type: :number, format: :double, minimum: -90, maximum: 90, example: 38.7223 }

      parameter name: :lng,
                in: :query,
                required: true,
                schema: { type: :number, format: :double, minimum: -180, maximum: 180, example: -9.1393 }

      response '200', 'nearest POI found' do
        schema '$ref' => '#/components/schemas/Poi'

        let(:lat) { 38.7223 }
        let(:lng) { -9.1393 }
        let(:factory) { RGeo::Geographic.spherical_factory(srid: 4326) }

        let!(:nearest_poi) do
          Poi.create!(
            name: 'Nearest POI',
            description: 'Closest point',
            location_point: factory.point(-9.14, 38.72)
          )
        end

        let!(:farther_poi) do
          Poi.create!(
            name: 'Farther POI',
            description: 'Farther point',
            location_point: factory.point(-8.6, 41.15)
          )
        end

        run_test! do |response|
          poi = JSON.parse(response.body)
          expect(poi['name']).to eq('Nearest POI')
        end
      end

      response '400', 'invalid request' do
        schema '$ref' => '#/components/schemas/Error'

        context 'when latitude is missing' do
          let(:lat) { nil }
          let(:lng) { -9.1393 }

          run_test!
        end

        context 'when longitude is missing' do
          let(:lat) { 38.7223 }
          let(:lng) { nil }

          run_test!
        end

        context 'when coordinates are invalid' do
          let(:lat) { 100 }
          let(:lng) { -9.1393 }

          run_test!
        end
      end
    end
  end
end
