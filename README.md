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

| Column | Description       |
| ------ | ----------------- |
| name   | City name         |
| region | Geographic region |
| lat    | Latitude          |
| lng    | Longitude         |

### pois.csv

| Column      | Description                   |
| ----------- | ----------------------------- |
| name        | POI name                      |
| description | Brief description             |
| lat         | Latitude                      |
| lng         | Longitude                     |
| categories  | Comma-separated category list |

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

## Architecture Decisions

### Data Structure

I first chose to start by designing the database structure. 3 things must be stored separately:

- Locations
- Points of Interest (POI)
- Categories

Thinking about the best way of storing the categories I reached these 2 options:

- Option 1: Two table design (no category table)
  This would mean having a categories column (probably a JSON or text column) on the POI table. The only pro I see for this approach is simplicity. Cons would include being unable to effectively query by category without parsing text and schema changes would be harder in the future (such as adding a created_at field). It would limit future features, like filtering by category popularity.

- Option 2: Three tables with a join table
  Pros for this approach include query flexibility (being able to query for questions like show me all POIs of a specific category), data consistency (all category names live in one table, this means we can normalize data at the source, to avoid differences like "beach" and "Beach"), and future proofing (if in the future we want to add a created_at column or track which POIs most commonly use each category). Only con I see would be database overhead.

I opted to go with option 2. While option 1 would be simpler it would limit the future features this app could have.

### Importing Data

I then started thinking about the best way to import data from the CSV files. There are 3 options:

- Option 1: Rake task
  Pros include having a clear separation of concerns (importing data is a separate task), and being easy to test. Cons would include being a bit overkill for quick local development.

- Option 2: Seeds file
  Pros are simplicity, a single file approach, as well as running a single command and loading everything. Cons are mixing 2 responsibilities (seeding vs importing external data) and being harder to test.

- Option 3: Using a gem
  Pros include having to write less code and handling easy to miss edge cases. Cons include adding a dependency (another thing to maintain and update), being a bit too much for simple structured CSV data, and having to learn a new library's API.

I'll import the CSV files directly in db/seeds.rb since these represent the initial dataset for the challenge. This keeps setup simple and allows running rails db:seed to populate the database immediately. I thought about using a rake task to enforce separation of concerns, but I think that would be overengineering for this case since these csv files are the initial data for the exercise.

### Preventing Duplicates

Next step is preventing duplicates while importing data, since the CSV structure may change. There are 2 options:

- Option 1: Check existence before creating
  This works but is slow for large files, hits the database once for every row.

- Option 2: Upsert in batch with unique constraints
  This is more efficient since it's a single SQL statement, that will either insert or update each row without creating duplicates. It's faster and handles everything automatically.

I decided to go with option 2.

### Import Error Handling

- Option 1: Log and skip bad rows
  This is the choice that makes sense when faulty data is expected.

- Option 2: Transaction rollback
  Pros include data consistency, but cons are that it will be slow for large datasets, and that we may need to re-import everything after failure. It's an all or nothing approach.

- Option 3: Import after validation
  With this option we first validate data, and only import it after ensuring the data is good. Pros are having clear failures (we can see exactly what's wrong before importing, and fix it), this also works towards good user experience. Cons include passing over data twice (slow for large files) and still having the all or nothing approach of option 2.

I'll validate the CSV structure and content before importing. This catches missing columns, invalid coordinates, and other issues before touching the database. For this small dataset, it's only a few extra lines of code and gives clear feedback about what needs fixing.

### Storing Location Coordinates

Thinking about how to store coordinates I reached these 3 options:

- Option 1: Text columns for latitude and longitude
  Pros are being easy to export in simple formats like CSV or JSON, as well as working with any database system. Cons are being unable to use spatial queries, needing manual math (for distance calculations), and no special indexing (slow for finding nearby locations). This approach throws away the built-in spatial functions of PostGIS, so I'm not moving forward with it.

- Option 2: GeoJSON text column
  Pros are that this is a standard format that works with any mapping library (like Google Maps or Leaflet), and being easy to export/import in JSON API responses. Cons include having no native spatial functions (like option 1), and the database not recognizing this as a point, even though it contains coordinates.

- Option 3: Native PostGIS geometry columns
  Pros include removing manual math by using built-in spatial functions, GiST indexes (we can create GiST indexes to efficiently support spatial queries such as finding nearby POIs), and type safety (db validates that values are valid geometry points).

I opted for option 3 because spatial queries are a core requirement, and PostGIS provides the appropriate data types, functions, and indexing for this use case.

### Database Schema

The migrations create 4 tables:

- locations, with a name, region and location_point
- pois, with a name, description and location_point
- categories, with a name
- categories_pois, which connects POIs and categories

I chose to keep locations, POIs and categories in separate tables. Categories are connected to POIs through a join table because both sides can have multiple related records. This also makes it easier to query POIs by category without storing and parsing a list of categories on the POI itself.
Names and regions use string because they are short values, while POI descriptions use text because they do not need an artificial length limit. The name and coordinate fields are required because a record without them would not be useful to the application.
Locations and POIs store their coordinates as geometry(Point,4326). This keeps the coordinate data in a format PostGIS can use for spatial queries, such as finding nearby POIs. The index choices and their implementation details are documented in the migration files.

### API Response Format

I considered whether the controllers should return HTML views or JSON responses.

- Option 1: HTML views
  This would allow Rails to render the frontend directly from controller actions. This could be useful if I decide to implement the frontend bonus using Rails views, but it would not directly satisfy the REST API requirement.

- Option 2: JSON responses
  This keeps the backend focused on providing the REST API and allows any frontend to consume the API independently. It also leaves the option of adding a Rails-based frontend later without changing the underlying data model.

I opted for JSON responses because the core requirement is a REST API. If I implement the frontend bonus later, I can add Rails views without changing the database structure or the API's underlying data.

### API Structure

For the API, I considered whether to treat trip planning as a traditional resource or as an operation.

- Option 1: Resource-based controllers
  This would mean having controllers that map directly to database resources, such as LocationsController and PoisController. This fits Rails conventions well and makes the API endpoints easy to understand. Trip planning would still need a separate endpoint because a trip is not stored in the database.

- Option 2: A single controller for the entire API
  This would keep all endpoints in one place, but would mix responsibilities and make the controller harder to maintain as more functionality is added.

I opted for separate controllers based on the main API responsibilities. Locations and POIs are persisted resources, so they have their own controllers. Trip planning is an operation rather than a persisted resource, so it will have its own controller without requiring a Trip model.

### Testing

For testing I considered 2 options:

- Option 1: Integration tests
  These test the application through HTTP requests and verify that the different parts work together as expected.

- Option 2: Unit tests
  These test individual pieces of application logic in isolation, making it easier to cover more complex logic and edge cases.

I'll use both. Integration tests will cover the API behaviour, while unit tests will cover application logic that makes sense to test separately.

### Test-Driven Development

I'm using TDD by writing the tests before the implementation, rather than just making tests pass for already developed functionality.

### Locations

I will start by implementing the Locations before the more complex POI and trip planning endpoints. Locations are a relatively simple resource and this provides a way to establish the structure and response format before implementing the more complex spatial queries.

The API will initially support:

- GET /locations to browse available locations, with an optional name filter
- GET /locations/:id to view a specific location

### Categories

The only endpoint I'll do for now is:

- GET /categories to fetch all categories

I'm creating this endpoint just so that a future frontend may fetch it for filtering purposes, instead of hardcoding them.

### POIs

I will implement the POI endpoints after Locations and Categories. POIs are more complex because they have categories and geographic coordinates.

The API will support:

- GET /pois to browse available POIs, with optional name and category filter
- GET /pois/:id to view a specific POI

### Trip Planning

This is the most complex part of the API because it needs to use the geographic coordinates of the origin, destination, and POIs to determine which POIs are along the route and return them in order.

The API will support:

- GET /trip-planning to plan a route between an origin and destination, returning the requested number of POIs along the route, with an optional category filter

The challenge does not define exactly how to decide whether a POI is along the route, or how to choose the requested number when there are more POIs available. I will make these choices based on keeping the implementation simple while still making the result useful.

#### Determining whether a POI is along the route

There are a few possible approaches:

- Option 1: Straight-line route + threshold
  Consider a POI part of the route if it is within a certain distance of the line. This is simple and can be handled entirely with PostGIS.

- Option 2: Actual driving route
  Use a routing service to calculate the road route and find POIs near it. This would be more realistic, but adds an external dependency and more complexity.

I will use the straight line with a distance threshold. It keeps the implementation self-contained and is sufficient for the scope of this challenge.

The route is defined by the origin and destination. I will keep this route fixed when evaluating and ordering POIs rather than recalculating it after each selected POI. Recalculating the route after each stop would turn the problem into planning a sequence of intermediate stops, which is beyond the scope of the challenge.

#### Distance threshold

The challenge does not define a distance threshold for determining whether a POI is along the route. I considered deriving the threshold from the distance between POIs and the provided locations, but the POIs are not explicitly associated with a location and some are intentionally distributed far beyond the nearest listed location. Using the furthest such distance would therefore make the route corridor unnecessarily broad.

Instead, I will use a fixed 10 km threshold based on the geographic distribution of the provided dataset. This provides a reasonable tolerance for considering a POI to be along a trip without including POIs that are significantly off the route.

The same threshold is applied to the fixed origin-to-destination line for each trip.

#### Service object structure

The trip planning logic will be handled by a dedicated service because it contains enough application logic to keep it out of the controller.

There are a few ways I could structure the trip planning service:

- Option 1: Use an instance with initialize to store the origin, destination, category, and number of POIs, then call plan.

- Option 2: Use plan as a class method and pass everything it needs directly to it.

Option 1 makes more sense when the service needs to keep state or dependencies that are shared across several operations. Option 2 is simpler when the operation is stateless and everything it needs is provided as input.

I will use Option 2 because trip planning is currently a single stateless operation. There is no useful state that needs to be stored between method calls, so creating a service instance just to call `plan` would add unnecessary structure.

#### Selecting the requested POIs

If more POIs are available than requested, there are a few options:

- Option 1: Return the ones closest to the origin.

- Option 2: Return the ones closest to the destination.

- Option 3: Spread them across the route.

The first two are simple, but can result in all the stops being concentrated in one part of the trip. I will instead spread the selected POIs across the route, choosing them at roughly even intervals.

The category filter will be applied before selecting the POIs, so only matching POIs are considered.

If fewer POIs are available than requested, I will return all matching POIs.
