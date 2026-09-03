source "https://rubygems.org"

ruby ">= 3.3.0"

# Rails 8 - API mode
gem "rails", "~> 8.0"

# Database - PostgreSQL with PostGIS
gem "pg", "~> 1.5"
gem "activerecord-postgis-adapter", "~> 11.0"

# Spatial data handling
gem "rgeo"
gem "rgeo-geojson"

# Markdown rendering for welcome page
gem "redcarpet"

# JSON serialization
gem "oj", "~> 3.16"

# Server
gem "puma", ">= 5.0"

# Windows timezone data
gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  gem "debug", platforms: %i[mri], require: "debug/prelude"
  gem "rspec-rails", "~> 7.0"
  gem "factory_bot_rails", "~> 6.4"
end

group :development do
  gem "rubocop", "~> 1.60", require: false
  gem "rubocop-rails", "~> 2.23", require: false
  gem "rubocop-rspec", "~> 2.26", require: false
end

group :test do
  gem "shoulda-matchers", "~> 6.0"
  gem "database_cleaner-active_record", "~> 2.1"
end

# Add any additional gems you find useful below this line
# For example, you might want to add API documentation gems
