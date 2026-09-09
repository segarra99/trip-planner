# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Categories API', type: :request do
  path '/categories' do
    get 'List categories' do
      tags 'Categories'
      produces 'application/json'
      description 'Returns all available categories.'

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

      response '200', 'categories found' do
        schema type: :object,
               properties: {
                 categories: {
                   type: :array,
                   items: {
                     '$ref' => '#/components/schemas/Category'
                   }
                 },
                 pagination: {
                   '$ref' => '#/components/schemas/Pagination'
                 }
               },
               required: %w[categories pagination]

        context 'when categories exist' do
          before do
            Category.create!(name: 'Beach')
            Category.create!(name: 'Museum')
          end

          run_test! do |response|
            body = response_body(response)

            expect(body['categories'].map { |category| category['name'] })
              .to contain_exactly('Beach', 'Museum')

            expect(body['pagination']).to eq(
              'page' => 1,
              'per_page' => 10,
              'total' => 2,
              'total_pages' => 1
            )
          end
        end

        context 'when pagination params are provided' do
          before do
            5.times do |index|
              Category.create!(name: "Category #{index + 1}")
            end
          end

          let(:page) { 2 }
          let(:per_page) { 2 }

          run_test! do |response|
            body = response_body(response)

            expect(body['categories'].map { |category| category['name'] })
              .to eq(['Category 3', 'Category 4'])

            expect(body['pagination']).to eq(
              'page' => 2,
              'per_page' => 2,
              'total' => 5,
              'total_pages' => 3
            )
          end
        end

        context 'when the requested page is beyond the last page' do
          before do
            3.times do |index|
              Category.create!(name: "Category #{index + 1}")
            end
          end

          let(:page) { 5 }
          let(:per_page) { 2 }

          run_test! do |response|
            body = response_body(response)

            expect(body['categories']).to eq([])

            expect(body['pagination']).to eq(
              'page' => 5,
              'per_page' => 2,
              'total' => 3,
              'total_pages' => 2
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

  def response_body(response)
    JSON.parse(response.body)
  end
end
