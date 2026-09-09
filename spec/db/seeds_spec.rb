# frozen_string_literal: true

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

  describe 'CSV validation' do
    let(:data_path) { Rails.root.join('data') }

    around do |example|
      original_locations = File.read(data_path.join('locations.csv'))
      original_pois = File.read(data_path.join('pois.csv'))

      example.run
    ensure
      File.write(data_path.join('locations.csv'), original_locations)
      File.write(data_path.join('pois.csv'), original_pois)
    end

    it 'rejects locations CSV files with invalid headers' do
      locations_csv = <<~CSV
        name,region,latitude,longitude
        Lisboa,Lisboa,38.7223,-9.1393
      CSV

      File.write(data_path.join('locations.csv'), locations_csv)

      expect { run_seed }
        .to raise_error(
          RuntimeError,
          'Invalid locations.csv headers. Expected: name, region, lat, lng'
        )

      expect(Location.count).to eq(0)
      expect(Poi.count).to eq(0)
      expect(Category.count).to eq(0)
    end

    it 'rejects POI CSV files with invalid headers' do
      pois_csv = <<~CSV
        name,description,latitude,longitude,categories
        Costa Nova,Beach in Portugal,40.6178,-8.7497,beach
      CSV

      File.write(data_path.join('pois.csv'), pois_csv)

      expect { run_seed }
        .to raise_error(
          RuntimeError,
          'Invalid pois.csv headers. Expected: name, description, lat, lng, categories'
        )

      expect(Location.count).to eq(0)
      expect(Poi.count).to eq(0)
      expect(Category.count).to eq(0)
    end

    it 'rejects non-numeric location coordinates' do
      locations_csv = <<~CSV
        name,region,lat,lng
        Lisboa,Lisboa,invalid,-9.1393
      CSV

      File.write(data_path.join('locations.csv'), locations_csv)

      expect { run_seed }
        .to raise_error(ArgumentError)

      expect(Location.count).to eq(0)
      expect(Poi.count).to eq(0)
      expect(Category.count).to eq(0)
    end

    it 'rejects non-numeric POI coordinates' do
      pois_csv = <<~CSV
        name,description,lat,lng,categories
        Costa Nova,Beach in Portugal,invalid,-8.7497,beach
      CSV

      File.write(data_path.join('pois.csv'), pois_csv)

      expect { run_seed }
        .to raise_error(ArgumentError)

      expect(Location.count).to eq(0)
      expect(Poi.count).to eq(0)
      expect(Category.count).to eq(0)
    end

    it 'rejects location coordinates outside the valid latitude range' do
      locations_csv = <<~CSV
        name,region,lat,lng
        Lisboa,Lisboa,91,-9.1393
      CSV

      File.write(data_path.join('locations.csv'), locations_csv)

      expect { run_seed }
        .to raise_error(
          RuntimeError,
          'Invalid coordinates for Lisboa: 91.0, -9.1393'
        )

      expect(Location.count).to eq(0)
      expect(Poi.count).to eq(0)
      expect(Category.count).to eq(0)
    end

    it 'rejects location coordinates outside the valid longitude range' do
      locations_csv = <<~CSV
        name,region,lat,lng
        Lisboa,Lisboa,38.7223,181
      CSV

      File.write(data_path.join('locations.csv'), locations_csv)

      expect { run_seed }
        .to raise_error(
          RuntimeError,
          'Invalid coordinates for Lisboa: 38.7223, 181.0'
        )

      expect(Location.count).to eq(0)
      expect(Poi.count).to eq(0)
      expect(Category.count).to eq(0)
    end

    it 'rejects POI coordinates outside the valid latitude range' do
      pois_csv = <<~CSV
        name,description,lat,lng,categories
        Costa Nova,Beach in Portugal,91,-8.7497,beach
      CSV

      File.write(data_path.join('pois.csv'), pois_csv)

      expect { run_seed }
        .to raise_error(
          RuntimeError,
          'Invalid coordinates for Costa Nova: 91.0, -8.7497'
        )

      expect(Location.count).to eq(0)
      expect(Poi.count).to eq(0)
      expect(Category.count).to eq(0)
    end

    it 'rejects POI coordinates outside the valid longitude range' do
      pois_csv = <<~CSV
        name,description,lat,lng,categories
        Costa Nova,Beach in Portugal,40.6178,181,beach
      CSV

      File.write(data_path.join('pois.csv'), pois_csv)

      expect { run_seed }
        .to raise_error(
          RuntimeError,
          'Invalid coordinates for Costa Nova: 40.6178, 181.0'
        )

      expect(Location.count).to eq(0)
      expect(Poi.count).to eq(0)
      expect(Category.count).to eq(0)
    end

    it 'validates both CSV files before importing any records' do
      invalid_pois_csv = <<~CSV
        name,invalid_description,lat,lng,categories
        Costa Nova,Beach in Portugal,40.6178,-8.7497,beach
      CSV

      File.write(data_path.join('pois.csv'), invalid_pois_csv)

      expect { run_seed }
        .to raise_error(RuntimeError)

      expect(Location.count).to eq(0)
      expect(Poi.count).to eq(0)
      expect(Category.count).to eq(0)
    end
  end
end
