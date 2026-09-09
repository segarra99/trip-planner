## Test-Driven Development

I'm using TDD by writing the tests before the implementation, rather than just making tests pass for already developed functionality.

### Testing

For testing I considered 2 options:

- **Option 1: Integration tests**

    These test the application through HTTP requests and verify that the different parts work together as expected.

- **Option 2: Unit tests**

    These test individual pieces of application logic in isolation, making it easier to cover more complex logic and edge cases.

**I'll use both.** Integration tests will cover the API behaviour, while unit tests will cover application logic that makes sense to test separately.

This also gives me flexibility to test the public API contract independently from the internal implementation of services and models.

## Environment Configuration

I considered whether to use `.env` files for configuration.

- **Option 1: `.env` files**

    The standard way to separate configuration from code, especially for secrets.

- **Option 2: Configuration directly in `docker-compose.yml`**

    Keeps all configuration in one place instead of splitting it across files.

**I opted for option 2.** This project only runs locally through Docker Compose, and the database credentials are disposable local values, not real secrets. A `.env` file would add a second place to manage configuration without an actual environment to vary it across.

This would need to change if the project introduced real secrets or a deployed environment.

## Data Structure

I first chose to start by designing the database structure. 3 things must be stored separately:

- Locations
- Points of Interest (POI)
- Categories

Thinking about the best way of storing the categories I reached these 2 options:

- **Option 1: Two table design (no category table)**

    This would mean having a categories column (probably a JSON or text column) on the POI table.

    The main advantage would be simplicity. The disadvantages would include being unable to effectively query by category without parsing text and making future schema changes harder.

    It would also limit future features, such as filtering by category popularity or storing additional category metadata.

- **Option 2: Three tables with a join table**

    Pros for this approach include query flexibility, data consistency and future proofing.

    It allows queries such as finding all POIs belonging to a specific category, keeps category names normalized in one place, and leaves room for additional attributes in the future.

    The main disadvantage is additional database structure.

**I opted for option 2.** While option 1 would be simpler, it would limit the future features this application could support.

I'm using HABTM for simplicity. If the relationship later needs attributes of its own, the join table can be promoted to a dedicated model.

## Database Schema

The migrations create 4 tables:

- `locations`, with a name, region and location_point
- `pois`, with a name, description and location_point
- `categories`, with a name
- `categories_pois`, which connects POIs and categories

I chose to keep locations, POIs and categories in separate tables. Categories are connected to POIs through a join table because both sides can have multiple related records.

This also makes it easier to query POIs by category without storing and parsing a list of categories on the POI itself.

Names and regions use string because they are short values, while POI descriptions use text because they do not need an artificial length limit.

The name and coordinate fields are required because a record without them would not be useful to the application.

Locations and POIs store their coordinates as `geometry(Point,4326)`. This keeps the coordinate data in a format PostGIS can use for spatial queries, such as finding nearby POIs.

### Automatic Timestamps on All Models

I enabled Rails' automatic timestamps (`t.timestamps`) on all tables:

- locations
- pois
- categories

This tracks when records are created and last modified.

While not explicitly required for this challenge, it's useful for audit trails and debugging data import issues.

## Storing Location Coordinates

Thinking about how to store coordinates I reached these 3 options:

- **Option 1: Text columns for latitude and longitude**

    Pros are being easy to export in simple formats like CSV or JSON, as well as working with any database system.

    Cons are being unable to use spatial queries, needing manual math for distance calculations, and no special indexing for spatial searches.

- **Option 2: GeoJSON text column**

    Pros are that this is a standard format that works with mapping libraries and is easy to export/import.

    Cons include having no native spatial functions and the database not recognizing the value as a spatial point.

- **Option 3: Native PostGIS geometry columns**

    Pros include spatial functions, GiST indexes for spatial queries, and database-level validation of geometry values.

**I opted for option 3** because spatial queries are a core requirement, and PostGIS provides the appropriate data types, functions and indexing for this use case.

## Preventing Duplicates

Next step is preventing duplicates while importing data, since the CSV structure may change.

There are 2 options:

- **Option 1: Check existence before creating**

    This works but can become slow for large files because it hits the database for every row.

- **Option 2: Upsert in batch with unique constraints**

    This is more efficient since the database can insert or update records without first performing a separate existence check.

**I decided to go with option 2.**

For locations and categories I prevent duplicate entries by adding a unique index on their respective name fields.

For POIs, there are 2 options:

- **Option 1: Unique constraint on name**

    This would prevent multiple POIs with the same name regardless of location, which doesn't make sense.

- **Option 2: Composite unique constraint on name + location_point**

    This allows different POIs to share names at different locations while preventing exact duplicates.

**I decided to go with option 2.**

This allows "Beach" to exist in multiple cities while still preventing the same POI from being imported twice.

## Importing Data

I considered 3 options:

- **Option 1: Rake task**

    This provides a clear separation between importing data and seeding the application, and would be easy to test independently.

- **Option 2: Seeds file**

    This keeps the setup simple and allows the entire initial dataset to be loaded with `rails db:seed`.

- **Option 3: Using a gem**

    This would reduce the amount of custom import code, but would introduce another dependency for relatively simple CSV data.

**I opted to import the CSV files directly in `db/seeds.rb`.**

These files represent the initial dataset for the challenge, so I don't think a separate import system is justified at this stage.

If the application later needed recurring imports, larger datasets or user-provided files, I would revisit this decision and introduce a dedicated import process.

### Category Import from CSV

The POI CSV contains a comma-separated categories column, which is parsed during import:

1. Categories are extracted and deduplicated.
2. Categories are inserted into the categories table if they do not already exist.
3. POIs are associated with their categories through the join table.

This keeps category data normalized while handling empty or duplicate category values in the source data.

## Import Error Handling

I considered 3 options:

- **Option 1: Log and skip bad rows**

    This can make sense when faulty data is expected and individual rows can safely be ignored.

- **Option 2: Transaction rollback**

    This provides all-or-nothing behaviour, but means the entire import fails because of one invalid record.

- **Option 3: Import after validation**

    Validate the dataset first and only write to the database after the data has passed validation.

**I opted for option 3.**

This catches missing columns, invalid coordinates and other structural problems before modifying the database.

For this small dataset, the additional validation cost is negligible and gives clearer feedback when the source data is invalid.

## API Structure

For the API, I considered whether to treat trip planning as a traditional resource or as an operation.

- **Option 1: Resource-based controllers**

    Controllers map directly to persisted resources such as Locations and POIs.

- **Option 2: A single controller for the entire API**

    This would keep all endpoints together, but would mix unrelated responsibilities.

**I opted for separate controllers.**

Locations and POIs are persisted resources, so they have their own controllers.

Trip planning is an operation rather than a persisted resource, so it has its own controller without requiring a Trip model.

## API Response Format

I considered whether the controllers should return HTML views or JSON responses.

- **Option 1: HTML views**

    This would allow Rails to render the frontend directly from controller actions.

- **Option 2: JSON responses**

    This keeps the backend focused on providing the REST API and allows any frontend to consume the API independently.

**I opted for JSON responses** because the core requirement is a REST API.

The frontend can therefore be implemented independently of the underlying API and database structure.

## Error Handling

The API returns appropriate HTTP status codes for invalid requests and missing resources.

- **400 Bad Request:** invalid or missing request parameters.
- **404 Not Found:** the requested resource does not exist.

I considered how to structure error responses for invalid requests and missing resources.

- **Option 1: Include full exception details**

    This could expose internal implementation details such as model names and stack traces.

- **Option 2: Simplified error messages**

    Return a consistent `error` field without exposing internal implementation details.

**I opted for option 2.**

The API returns:

```json
{ "error": "<message>" }
```

for validation errors and:

```json
{ "error": "<Model> not found" }
```

for missing resources.

This keeps the API response clean while still providing useful information to consumers.

## Locations

I started by implementing Locations before the more complex POI and trip planning endpoints.

Locations are a relatively simple resource, which establishes the general API structure and response format before introducing spatial queries.

The API supports:

- `GET /locations` to browse available locations, with an optional name filter
- `GET /locations/:id` to view a specific location

## Categories

The API supports:

- `GET /categories` to fetch categories

The endpoint allows a future frontend to retrieve the available categories instead of hardcoding them.

## POIs

POIs are more complex because they have both categories and geographic coordinates.

The API supports:

- `GET /pois` to browse available POIs, with optional name and category filters
- `GET /pois/:id` to view a specific POI
- `GET /pois/nearest` to find the closest POI to a given coordinate

## POI Response Consistency

All endpoints return POIs using the same response structure, including categories.

This keeps the API consistent and allows the same POI schema to be reused across endpoints.

## API Coordinate Response

I considered how to return coordinates in the API.

- **Option 1: Return the PostGIS point**

    This avoids conversion but exposes the database representation to API consumers.

- **Option 2: Return separate latitude and longitude fields**

    This is simpler for API consumers and keeps the database representation internal.

**I opted for option 2.**

The API returns latitude and longitude while PostGIS geometry is used internally for spatial queries.

## API Documentation

The API is documented using Swagger/OpenAPI.

The documentation describes the available endpoints, parameters, response structures and error responses.

I chose to keep the API documentation close to the implementation rather than maintaining a completely separate manual specification.

This makes the API contract easier to inspect during development and provides an interactive way to try the endpoints.

The Swagger documentation is also exposed through the application's shared navigation.

## Trip Planning

This is the most complex part of the API because it needs to use the geographic coordinates of the origin, destination and POIs to determine which POIs are along the route and return them in order.

The API supports:

- `GET /trip-planning` to plan a route between an origin and destination, returning the requested number of POIs along the route, with an optional category filter

The challenge does not define exactly how to decide whether a POI is along the route, or how to choose the requested number when there are more POIs available.

I therefore made these decisions based on keeping the implementation simple while still producing useful results.

### Determining whether a POI is along the route

There are a few possible approaches:

- **Option 1: Straight-line route + threshold**

    Consider a POI part of the route if it is within a certain distance of the line between the origin and destination.

    This is simple and can be handled entirely with PostGIS.

- **Option 2: Actual driving route**

    Use a routing service to calculate the road route and find POIs near it.

    This would be more realistic, but adds an external dependency and additional complexity.

**I originally chose option 1** because it kept the trip-planning algorithm self-contained and was sufficient for the initial scope of the challenge.

**(Refactored — see `Refactoring → Route Algorithm`.)**

The implementation now uses the actual driving route when the routing service is available, while retaining the original straight-line approach as a fallback.

### Distance threshold

The original implementation used a fixed **10 km threshold** based on the geographic distribution of the provided dataset.

This was intended to provide a reasonable tolerance without including POIs that were significantly away from the trip.

**(Refactored — see `Refactoring → Distance Threshold`.)**

After switching to actual route geometry, I increased the threshold to **20 km** because some stretches of the route had relatively few POIs within 10 km.

### Service object structure

The trip planning logic is handled by a dedicated service because it contains enough application logic to keep it out of the controller.

There are a few ways I could structure the service:

- **Option 1: Use an instance with `initialize`**

    Store the origin, destination, category and number of POIs, then call `plan`.

- **Option 2: Use `plan` as a class method**

    Pass everything the operation needs directly to it.

Option 1 makes more sense when a service needs to retain state or share dependencies across multiple operations.

Option 2 is simpler when the operation is stateless and everything it needs is provided as input.

**I use option 2** because trip planning is a stateless operation. Creating an instance just to call `plan` would add structure without providing a useful benefit.

### Selecting the requested POIs

If more POIs are available than requested, there are a few options:

- **Option 1: Return the ones closest to the origin.**
- **Option 2: Return the ones closest to the destination.**
- **Option 3: Spread them across the route.**

The first two are simple, but can result in all the stops being concentrated in one part of the trip.

**I originally used evenly spaced positions in the ordered POI list.**

This was a simple approximation that spread results reasonably well for the initial implementation.

**(Refactored — see `Refactoring → Selecting the requested POIs`.)**

The implementation now divides the route into sections and attempts to select POIs based on their position along the route.

This better represents the intent of selecting stops across the trip rather than simply selecting positions in an ordered collection.

The category filter is applied before selecting POIs, so only matching POIs are considered.

If fewer POIs are available than requested, all matching POIs are returned.

## Find Nearest POI

The API supports:

- `GET /pois/nearest`

I considered two ways to structure the endpoint:

- **Option 1: Add `nearest` to `PoisController` as a collection action.**
- **Option 2: Create a separate controller for the endpoint.**

**I opted for option 1** because the endpoint is still operating on the POI collection.

A separate controller would add structure without providing a meaningful separation of responsibility.

For the implementation, I also considered:

- **Option 1: Keep the query in `PoisController`.**
- **Option 2: Create a separate service for finding the nearest POI.**

**I opted for option 1** because the logic is simple: validate the coordinates and execute a single PostGIS query.

A service would be unnecessary abstraction for this operation.

The distance is calculated using PostGIS rather than Ruby.

## Pagination

I added pagination to `/locations`, `/categories` and `/pois` because these are collection endpoints and could contain a large number of records.

These endpoints are paginated by default using a default page and page size.

For `/trip-planning`, I considered 2 options:

- **Option 1: Do not paginate**

    This keeps the endpoint simple and allows the frontend to receive all selected POIs in a single response.

- **Option 2: Paginate**

    This makes the endpoint behave more like the other collection endpoints, but could require multiple requests when the frontend needs all the POIs for the map.

**I decided to use a middle ground.**

`/trip-planning` is not paginated by default, but supports pagination when `page` or `per_page` is provided.

This allows the frontend to receive all selected POIs by default while still supporting paginated results when needed.

Pagination is applied after the trip-planning query has selected and ordered the POIs.

This keeps route selection and ordering deterministic before pagination is applied.

## CI/CD

This project uses GitHub Actions for continuous integration.

The workflow runs on every push and pull request and consists of three steps:

1. **Build** the test Docker image:

    ```bash
    docker compose build test
    ```

2. **Lint** the codebase with RuboCop:

    ```bash
    docker compose --profile test run --rm --no-deps test bundle exec rubocop
    ```

    The database dependency is not required for linting.

3. **Test** the application:

    ```bash
    docker compose --profile test run --rm test
    ```

    This runs the full RSpec suite against PostgreSQL/PostGIS.

The workflow definition lives at `.github/workflows/ci.yml`.

### Running the same checks locally

To reproduce the CI pipeline locally before pushing:

```bash
docker compose build test
docker compose --profile test run --rm --no-deps test bundle exec rubocop
docker compose --profile test run --rm test
```

## Frontend

Since the frontend is a bonus, I wanted to keep it simple and avoid adding unnecessary infrastructure.

I considered two options:

- **Option 1: Separate frontend application**

    This could use React and communicate with the Rails API, but would add another application, dependencies, a build system and another Docker service.

- **Option 2: Rails-based frontend**

    Rails can render the frontend using its existing view layer, keeping everything in one application.

**I opted for option 2** because the bonus is small enough that a separate frontend application would add more complexity than value.

It also gave me an opportunity to work with a Rails-based frontend rather than defaulting to a framework I already know.

### Frontend API Access

I considered two ways for the frontend to get data:

- **Option 1: Use a Rails controller directly**

    The controller could access models and services and pass the data to the view.

- **Option 2: Consume the existing REST API**

    The frontend can call the existing API endpoints and use their responses.

**I opted for option 2** because the API already provides the functionality the frontend needs.

This avoids duplicating business logic in another controller and means the frontend consumes the same interface available to any other API client.

The frontend uses endpoints such as:

- `/locations`
- `/categories`
- `/trip-planning`

Endpoints such as `/pois/nearest` remain available as API functionality but are not needed by the frontend.

### JavaScript vs TypeScript

I considered two options:

- **Option 1: TypeScript**

    Provides type safety but requires additional tooling and configuration.

- **Option 2: JavaScript**

    Is sufficient for the size and scope of the frontend without introducing additional tooling.

**I opted for option 2** because the frontend is a small bonus feature and the additional setup of TypeScript is not justified for the current scope.

### Frontend Technologies

The frontend uses:

- Rails Views
- JavaScript
- Importmap
- Propshaft
- Leaflet
- OpenStreetMap
- OSRM

### Frontend Structure

I considered whether to split the JavaScript into multiple files.

- **Option 1: Multiple JavaScript files**

    This would separate responsibilities such as API requests, map handling and UI rendering.

- **Option 2: One JavaScript file**

    This keeps the frontend simple and makes the complete flow easy to follow.

**I opted for option 2** because the frontend is currently small enough that splitting it into multiple files would add more structure than value.

If the frontend grows significantly, I would revisit this decision.

### Map

I considered a few options for displaying the map:

- **Option 1: Google Maps**

    Mature mapping and routing functionality, but requires an API key and adds a dependency on Google's services.

- **Option 2: Mapbox**

    Provides maps and routing, but also requires an API key and adds another external service.

- **Option 3: Leaflet with OpenStreetMap**

    Leaflet is a lightweight mapping library and OpenStreetMap provides the map data.

**I opted for option 3** because it provides the required functionality without adding a large frontend dependency or requiring an API key.

### Map Markers

I considered two options:

- **Option 1: Leaflet default markers**

    Simpler, but all points would look the same.

- **Option 2: Custom Leaflet markers**

    Leaflet's `divIcon` allows markers to be created with HTML and styled with CSS.

**I opted for option 2** because it allows origin, destination and POIs to be visually distinguished and allows POI numbers to be displayed directly on the map.

The markers use:

- Green for the origin
- Red for the destination
- Blue numbered markers for POIs

### Route Display

I considered two options:

- **Option 1: Straight lines**

    Simple and does not require an external routing service, but does not represent the route a vehicle would actually take.

- **Option 2: Route following roads**

    A routing service can calculate a driving route between the origin, POIs and destination.

**I opted for option 2** because the frontend represents a road trip, so showing the actual driving route is more useful than showing straight lines between points.

### Routing Service

For calculating the driving route I considered:

- **Option 1: OSRM**

    Open-source routing engine that supports driving routes and multiple waypoints.

- **Option 2: GraphHopper**

    Provides routing and additional features, but adds another external service and API configuration.

- **Option 3: OpenRouteService**

    Provides routing using OpenStreetMap data, but also requires external API configuration.

**I opted for option 1** because OSRM provides the functionality needed for this challenge with minimal setup.

The frontend sends the origin, selected POIs and destination to OSRM.

The returned road geometry is then displayed using Leaflet.

### Trip Planning vs Route Display

Originally, the backend and frontend intentionally used different definitions of the route.

The backend used the straight origin-to-destination line and a distance threshold to determine which POIs were along the trip.

The frontend used OSRM to display the actual driving route.

This was initially a deliberate trade-off: keeping routing out of the backend made the API simpler and avoided an external dependency.

**(Refactored — see `Refactoring → Route Algorithm`.)**

The backend now also uses the actual driving route when possible.

This makes the POIs selected by the API more consistent with the route shown by the frontend.

The original straight-line algorithm remains available as a fallback when the routing service cannot be used.

### POI Panel

I wanted the selected POIs to be visible without requiring the user to click each map marker.

I considered two options:

- **Option 1: Show POIs only on the map**

    This keeps the interface smaller, but requires the user to interact with markers to see the POI information.

- **Option 2: Show POIs in a panel next to the map**

    This allows users to see the POIs, categories and descriptions at the same time as the map.

**I opted for option 2** because the map provides geographic information while the panel provides detailed information.

The POIs are displayed in route order and numbered to match their markers on the map.

Clicking a POI in the panel focuses its marker and opens its popup.

### Map and Panel Layout

I considered placing the POI panel above or below the map, but decided to place it beside the map on larger screens.

This allows the user to see the route and POI information at the same time.

On smaller screens the layout changes to a single column, with the map above the POI panel.

### Frontend Dependencies

I wanted to avoid adding dependencies where the existing Rails setup was enough.

The frontend therefore uses:

- **Leaflet** for the interactive map
- **OpenStreetMap** for map tiles
- **OSRM** for driving route calculation

No frontend framework or additional marker library is used.

Leaflet is loaded through Importmap and the frontend assets are served through Propshaft.

# Refactoring

The implementation changed in a few areas after I had a working version of the application.

I intentionally kept these changes documented rather than replacing the original decisions, because they show how the design changed after testing the actual behaviour of the system.

## Selecting the requested POIs

The original implementation selected POIs at roughly even positions in the ordered POI list.

After testing the frontend, I noticed that the selected POIs were often clustered around the origin and destination.

This happened because the dataset contains many more POIs near some parts of the route than others. Evenly spacing the indexes in the collection therefore does not necessarily produce an even geographic distribution.

I considered:

- **Option 1: Select evenly spaced POIs from the ordered list**

    Simple, but does not account for the geographic distribution of POIs.

- **Option 2: Divide the route into sections and select POIs based on their position along the route**

    Distributes POIs based on their geographic position rather than their position in the collection.

**I changed the implementation to option 2.**

The route position is represented between `0.0` and `1.0`, where `0.0` is the origin and `1.0` is the destination.

I divide this range into as many buckets as the requested number of POIs and try to select one POI from each bucket.

For example, requesting 4 POIs creates 4 sections:

```text
Origin                                      Destination
  |------------|------------|------------|------------|
       POI 1         POI 2        POI 3        POI 4
```

When a bucket contains multiple POIs, I select the one closest to its centre.

If a bucket is empty, I fill the remaining slots with unused POIs that are furthest from the POIs already selected.

This helps maximise the geographic spread of the selected POIs.

The category filter is applied before selection, so only matching POIs are considered.

If fewer POIs are available than requested, all matching POIs are returned.

## Preventing Identical Origin and Destination

I also added validation to prevent the origin and destination from being the same location.

The API returns `400 Bad Request` when they are identical.

In the frontend, the selected location is disabled in the other dropdown to prevent the same selection from being made.

This keeps the validation in the backend as the source of truth while also preventing an invalid selection in the UI.

## Multiple Category Filtering

I changed the trip-planning category filter to support multiple categories instead of a single category.

I considered two options:

- **Option 1: Match all selected categories**

    A POI would only be returned if it belongs to every selected category.

- **Option 2: Match any selected category**

    A POI would be returned if it belongs to at least one of the selected categories.

**I opted for option 2** because POIs can belong to multiple categories and users are likely selecting multiple interests they want to discover.

This provides a broader set of relevant stops rather than excluding POIs that only match one of the selected interests.

The API accepts multiple category IDs, the trip-planning service filters POIs against the selected categories, and the frontend category selector allows multiple selections.

## Route Algorithm

After finishing the exercise, I revisited the trip-planning algorithm to see if I could make it more useful for an actual road trip.

The original implementation used a straight line between the origin and destination and considered a POI to be along the route if it was within a certain distance of that line.

This was simple and worked for the scope of the exercise, but it did not represent how someone would actually travel between two locations.

I changed this to use the actual driving route.

The route is now calculated using a routing service, and the resulting road geometry is used with PostGIS to find POIs that are close to the route.

The frontend was already using a routing service to display the driving route on the map, so using the same concept for backend POI selection makes the API results more consistent with what is shown to the user.

### Routing Failure Fallback

Using a routing service introduces an external dependency.

I therefore did not want routing failures to make trip planning completely unavailable.

The original straight-line implementation is retained as a fallback.

If the routing service fails or is unavailable, the application falls back to the previous implementation instead of failing the entire trip-planning request.

### Routing Service Separation

To keep responsibilities separated, I extracted the routing logic into its own service.

`TripPlanningService` is responsible for finding and selecting POIs along the route.

`RoutingService` is responsible for communicating with the external routing service and returning route geometry.

This isolates the external dependency and makes it easier to replace the routing provider later.

## Distance Threshold

After switching from straight-line geometry to actual route geometry, I tested the trip-planning endpoint again.

The original 10 km threshold excluded POIs in stretches of the route where they were relatively sparse.

This left the bucket-selection algorithm with fewer candidates in some sections.

I therefore increased the threshold from **10 km to 20 km**.

The larger threshold brings more POIs into range along sparse sections of the route without noticeably including POIs that are clearly unrelated to the trip.

The decision is therefore a consequence of testing the actual algorithm rather than simply choosing a larger threshold in advance.

## Centralize API Response Serialization

I noticed duplication in how API responses were being serialized across the controllers.

I extracted the shared serialization logic into methods in the base controller.

This allows controllers to reuse the same serialization behaviour and keeps the response format consistent across endpoints.

## Test Refactoring

As the API grew, the test suite also grew to cover pagination, filtering, invalid pagination parameters and the different collection endpoints.

I refactored the test files so that related behaviours are grouped consistently and the API contract is easier to understand from the tests.

Pagination tests specifically cover:

- default pagination behaviour
- explicit `page`
- explicit `per_page`
- filtering together with pagination
- empty results
- invalid pagination parameters
- pagination across collection endpoints

The intention is not only to increase coverage, but to make the tests describe the API behaviour clearly.

## Swagger Schema Updates

As the API changed, I also updated the Swagger/OpenAPI schemas so that the documented contract stays aligned with the implementation.

This is particularly important for changes such as pagination and the updated response structures.

The Swagger documentation should therefore be treated as part of the API contract rather than as separate documentation that can drift from the implementation.

# Future Improvements

The current implementation covers the main requirements of the challenge.

If I had more time, I would focus on production hardening and areas where the current implementation has an obvious limitation rather than adding more features.

## Frontend Testing

The main application logic is covered by automated tests, but most of the frontend behaviour is currently tested manually.

I would add browser or JavaScript tests for the main interactions, including:

- category selection
- origin and destination validation
- loading states
- error states
- interaction between the POI list and the map
- route rendering

## Routing Service

The application currently uses the public OSRM service to calculate driving routes.

This works well for the challenge, but a production application would need more consideration around:

- timeouts
- rate limits
- service failures
- retry behaviour
- monitoring
- replacing the routing provider

The current `RoutingService` abstraction provides a useful boundary for making those changes without coupling the rest of the application directly to the external provider.

## Performance

The current dataset is relatively small, so the existing queries are sufficient.

If the amount of data increased, I would benchmark the PostGIS queries and category filtering and optimize them based on actual bottlenecks rather than adding indexes unnecessarily.

I would also revisit whether pagination should be applied differently depending on the endpoint and expected dataset size.

## API Structure

The API is intentionally kept simple, with controllers handling validation and response formatting.

If the API became significantly larger, I would consider moving some of this logic into dedicated serializers or other objects.

The current structure is deliberately proportional to the size of the application rather than introducing abstractions before they are needed.

## Accessibility

The frontend was mainly built around the requirements of the challenge.

With more time, I would do a dedicated accessibility pass, particularly around:

- keyboard navigation
- focus handling
- screen-reader support
- map interaction
- the custom category selector

The custom category selector should support keyboard focus, navigation and selection rather than relying only on mouse interaction.

## Monitoring

The application currently relies on logging provided by the container and hosting platform.

For a production application, I would add:

- error tracking
- structured logs
- basic application metrics
- monitoring for failures from the external routing service

This would make it easier to identify and investigate problems in production.

## Deployment

The application is containerized and can be deployed to a container-based hosting platform.

With more time, I would add deployment automation for a specific hosting provider, including:

- running migrations
- handling the initial data import
- configuring production environment variables
- health checks
- deployment rollback considerations

## Environment Configuration

Configuration currently lives directly in `docker-compose.yml`, which is reasonable while the project only runs locally with disposable credentials.

If the project were deployed or introduced real secrets, I would move those values to environment variables managed outside the repository and reference them from `docker-compose.yml`.

This keeps the current local setup simple without treating local disposable credentials as if they were production secrets.
