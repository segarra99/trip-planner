require 'csv'

# Expected columns in each CSV file.
# These are used to validate the CSV structure before importing.
LOCATION_HEADERS = %w[name region lat lng].freeze
POI_HEADERS = %w[name description lat lng categories].freeze

# Creates PostGIS points
POINT_FACTORY = RGeo::Geographic.spherical_factory(srid: 4326)

# Reads a CSV file and validates that it has the expected columns.
def csv_rows(filename, expected_headers)
  csv = CSV.read(Rails.root.join('data', filename), headers: true)

  raise "Invalid #{filename} headers. Expected: #{expected_headers.join(', ')}" unless csv.headers == expected_headers

  csv
end

# Converts the latitude and longitude from a CSV row into a PostGIS point.
# Coordinates are validated before the point is created.
def point_from(row)
  latitude = Float(row.fetch('lat'))
  longitude = Float(row.fetch('lng'))

  unless latitude.between?(-90, 90) && longitude.between?(-180, 180)
    raise "Invalid coordinates for #{row.fetch('name')}: #{latitude}, #{longitude}"
  end

  POINT_FACTORY.point(longitude, latitude)
end

# Read and validate the CSV files before starting the transaction.
locations = csv_rows('locations.csv', LOCATION_HEADERS)
pois = csv_rows('pois.csv', POI_HEADERS)

# Import everything in one transaction so a failure rolls back the entire import.
ApplicationRecord.transaction do
  # Import locations in bulk.
  # The unique index on name prevents duplicate locations.
  Location.upsert_all(
    locations.map do |row|
      {
        name: row.fetch('name').strip,
        region: row.fetch('region').strip,
        location_point: point_from(row)
      }
    end,
    unique_by: :index_locations_on_name
  )

  # Extract the unique category names from the POI data.
  categories = pois.flat_map { |row| row.fetch('categories').split(',') }
                   .map(&:strip)
                   .reject(&:empty?)
                   .uniq


  # Import categories in bulk.
  # The unique index on name prevents duplicate categories.
  Category.upsert_all(
    categories.map { |name| { name: name } },
    unique_by: :index_categories_on_name
  )

  # Import POIs in bulk.
  # The unique index on name and location prevents duplicate POIs.
  Poi.upsert_all(
    pois.map do |row|
      {
        name: row.fetch('name').strip,
        description: row.fetch('description').strip,
        location_point: point_from(row)
      }
    end,
    unique_by: :index_pois_on_name_and_location_point
  )
  # Associate each POI with its categories through the join table.
  pois.each do |row|
    poi = Poi.find_by!(
      name: row.fetch('name').strip,
      location_point: point_from(row)
    )

    row.fetch('categories')
       .split(',')
       .map(&:strip)
       .reject(&:empty?)
       .uniq
       .each do |category_name|
         category = Category.find_by!(name: category_name)
         poi.categories << category unless poi.categories.include?(category)
    end
  end
end
