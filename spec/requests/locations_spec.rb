# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Locations API', type: :request do
  let(:factory) do
    RGeo::Geographic.spherical_factory(srid: 4326)
  end

  path '/locations' do
    get 'List locations' do
      tags 'Locations'
      produces 'application/json'
      description 'Returns all locations, optionally filtered by name.'

      parameter name: :name,
                in: :query,
                required: false,
                description: 'Filter by location name',
                schema: {
                  type: :string,
                  example: 'Lisboa'
                }

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
                description: 'Number of results per page',
                schema: {
                  type: :integer,
                  default: 10,
                  example: 10
                }

      response '200', 'locations found' do
        schema type: :object,
               properties: {
                 locations: {
                   type: :array,
                   items: {
                     '$ref' => '#/components/schemas/Location'
                   }
                 },
                 pagination: {
                   '$ref' => '#/components/schemas/Pagination'
                 }
               },
               required: %w[locations pagination]

        context 'when no pagination params are provided' do
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

          run_test! do |response|
            body = response_body(response)

            expect(body['locations'].map { |location| location['name'] })
              .to contain_exactly('Lisboa', 'Porto')

            expect(body['pagination']).to eq(
              'page' => 1,
              'per_page' => 10,
              'total' => 2,
              'total_pages' => 1
            )
          end
        end

        context 'when pagination params are provided' do
          let!(:locations) do
            5.times.map do |index|
              Location.create!(
                name: "Location #{index + 1}",
                region: 'Region',
                location_point: factory.point(-9.0 + index, 38.0 + index)
              )
            end
          end

          let(:page) { 2 }
          let(:per_page) { 2 }

          run_test! do |response|
            body = response_body(response)

            expect(body['locations'].map { |location| location['name'] })
              .to eq(['Location 3', 'Location 4'])

            expect(body['pagination']).to eq(
              'page' => 2,
              'per_page' => 2,
              'total' => 5,
              'total_pages' => 3
            )
          end
        end

        context 'when the requested page is beyond the last page' do
          let!(:locations) do
            3.times.map do |index|
              Location.create!(
                name: "Location #{index + 1}",
                region: 'Region',
                location_point: factory.point(-9.0 + index, 38.0 + index)
              )
            end
          end

          let(:page) { 5 }
          let(:per_page) { 2 }

          run_test! do |response|
            body = response_body(response)

            expect(body['locations']).to eq([])

            expect(body['pagination']).to eq(
              'page' => 5,
              'per_page' => 2,
              'total' => 3,
              'total_pages' => 2
            )
          end
        end

        context 'when filtering by name' do
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

          let(:name) { 'Lisboa' }

          run_test! do |response|
            body = response_body(response)

            expect(body['locations'].map { |location| location['name'] })
              .to eq(['Lisboa'])

            expect(body['pagination']).to eq(
              'page' => 1,
              'per_page' => 10,
              'total' => 1,
              'total_pages' => 1
            )
          end
        end
      end

      response '400', 'invalid pagination parameters' do
        schema type: :object,
               properties: {
                 error: {
                   type: :string
                 }
               },
               required: ['error']

        context 'when page is invalid' do
          let(:page) { 0 }

          run_test! do |response|
            expect(response_body(response)).to eq(
              'error' => 'invalid pagination parameters'
            )
          end
        end

        context 'when per_page exceeds the maximum' do
          let(:per_page) { 101 }

          run_test! do |response|
            expect(response_body(response)).to eq(
              'error' => 'invalid pagination parameters'
            )
          end
        end
      end
    end
  end

  path '/locations/{id}' do
    get 'Retrieve a location' do
      tags 'Locations'
      produces 'application/json'
      description 'Returns a single location by ID.'

      parameter name: :id,
                in: :path,
                required: true,
                schema: {
                  type: :integer,
                  example: 1
                }

      response '200', 'location found' do
        schema '$ref' => '#/components/schemas/Location'

        context 'when location exists' do
          let(:id) do
            Location.create!(
              name: 'Lisboa',
              region: 'Lisboa',
              location_point: factory.point(-9.1393, 38.7223)
            ).id
          end

          run_test! do |response|
            body = response_body(response)

            expect(body['id']).to eq(id)
            expect(body['name']).to eq('Lisboa')
            expect(body['region']).to eq('Lisboa')
          end
        end
      end

      response '404', 'location not found' do
        schema '$ref' => '#/components/schemas/Error'

        context 'when location does not exist' do
          let(:id) { 999_999 }

          run_test!
        end
      end
    end
  end

  def response_body(response)
    JSON.parse(response.body)
  end
end
