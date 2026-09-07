require 'rails_helper'

RSpec.describe 'database seeds' do
  def run_seed
    Rails.application.load_seed
  end

  before do
    Category.delete_all
    Poi.delete_all
    Location.delete_all
  end

  describe 'loading the seed' do
    it 'creates locations' do
      run_seed

      expect(Location.count).to be > 0
      expect(Location.pluck(:name)).to include('Lisboa', 'Porto')
    end

    it 'creates categories' do
      run_seed

      expect(Category.count).to be > 0
      expect(Category.pluck(:name)).to include('beach', 'culture')
    end

    it 'creates pois' do
      run_seed

      expect(Poi.count).to be > 0
      expect(Poi.pluck(:name)).to include('Costa Nova')
    end

    it 'associates pois with their categories' do
      run_seed

      costa_nova = Poi.find_by!(name: 'Costa Nova')

      expect(costa_nova.categories.pluck(:name))
        .to match_array(%w[beach culture])
    end

    it 'creates valid location points' do
      run_seed

      expect(Location.where(location_point: nil)).to be_empty
    end

    it 'creates valid poi points' do
      run_seed

      expect(Poi.where(location_point: nil)).to be_empty
    end

    it 'does not create duplicate records when run multiple times' do
      run_seed

      locations_count = Location.count
      categories_count = Category.count
      pois_count = Poi.count
      associations_count = ActiveRecord::Base.connection.select_value(
        'SELECT COUNT(*) FROM categories_pois'
      ).to_i

      run_seed

      expect(Location.count).to eq(locations_count)
      expect(Category.count).to eq(categories_count)
      expect(Poi.count).to eq(pois_count)
      expect(
        ActiveRecord::Base.connection.select_value('SELECT COUNT(*) FROM categories_pois').to_i
      ).to eq(associations_count)
    end
  end
end
