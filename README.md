# Roadtrip Designer - Starter Kit

This starter kit provides the infrastructure for the Indie Campers technical challenge.

## Prerequisites

- Docker and Docker Compose installed
- Git

## Getting Started

### 1. Start the services

```bash
docker-compose up
```

This will:
- Start a PostgreSQL database with PostGIS extension
- Build and start the Rails application
- Visit http://localhost:3000 to see this README

### 2. Build your application

The starter kit provides a minimal Rails 8 API application. You'll need to:
- Design your data models
- Create migrations
- Build your API endpoints
- Import the provided CSV data

### 3. Import the data

The `data/` folder contains:
- `locations.csv` - Portuguese cities that serve as trip origins/destinations
- `pois.csv` - Points of Interest across Portugal

Create a mechanism to import this data into your database (rake task, seeds, etc.).

## Data Files

### locations.csv

| Column | Description |
|--------|-------------|
| name | City name |
| region | Geographic region |
| lat | Latitude |
| lng | Longitude |

### pois.csv

| Column | Description |
|--------|-------------|
| name | POI name |
| description | Brief description |
| lat | Latitude |
| lng | Longitude |
| categories | Comma-separated category list |

## Useful Commands

```bash
# Start services
docker-compose up

# Run in background
docker-compose up -d

# View logs
docker-compose logs -f web

# Access Rails console
docker-compose exec web bundle exec rails console

# Run migrations
docker-compose exec web bundle exec rails db:migrate

# Run tests
docker-compose exec web bundle exec rspec

# Generate a model
docker-compose exec web bundle exec rails generate model Location name:string

# Stop services
docker-compose down
```

## PostGIS Basics

PostGIS extends PostgreSQL with spatial capabilities. Some useful functions:

```sql
-- Create a point from lat/lng
ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)

-- Calculate distance between two points (in meters)
ST_Distance(point1::geography, point2::geography)

-- Find points within a distance
ST_DWithin(point1::geography, point2::geography, distance_in_meters)

-- Check if a point is within a polygon/line buffer
ST_Within(point, ST_Buffer(line::geography, distance))
```

## Resources

- [Rails 8 API Mode](https://guides.rubyonrails.org/api_app.html)
- [PostGIS Documentation](https://postgis.net/documentation/)
- [RGeo Gem](https://github.com/rgeo/rgeo)
- [ActiveRecord PostGIS Adapter](https://github.com/rgeo/activerecord-postgis-adapter)

---

Good luck!
