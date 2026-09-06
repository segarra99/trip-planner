require 'rails_helper'

RSpec.describe 'Categories API', type: :request do
  describe 'GET /categories' do
    it 'returns all categories' do
      Category.create!(name: 'Beach')
      Category.create!(name: 'Museum')

      get '/categories'

      expect(response).to have_http_status(:ok)

      categories = JSON.parse(response.body)

      expect(categories.length).to eq(2)
      expect(categories.map { |category| category['name'] }).to contain_exactly(
        'Beach',
        'Museum'
      )
    end
  end
end
