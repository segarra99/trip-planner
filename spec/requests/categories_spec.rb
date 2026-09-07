require 'swagger_helper'

RSpec.describe 'Categories API', type: :request do
  path '/categories' do
    get 'List categories' do
      tags 'Categories'
      produces 'application/json'
      description 'Returns all available categories.'

      response '200', 'categories found' do
        schema type: :array,
               items: {
                 '$ref' => '#/components/schemas/Category'
               }

        before do
          Category.create!(name: 'Beach')
          Category.create!(name: 'Museum')
        end

        run_test! do |response|
          categories = JSON.parse(response.body)

          expect(categories.length).to eq(2)
          expect(categories.map { |category| category['name'] }).to contain_exactly(
            'Beach',
            'Museum'
          )
        end
      end
    end
  end
end
