### Test-Driven Development

I'm using TDD by writing the tests before the implementation, rather than just making tests pass for already developed functionality.

### Testing

For testing I considered 2 options:

- **Option 1: Integration tests**

    These test the application through HTTP requests and verify that the different parts work together as expected.

- **Option 2: Unit tests**

    These test individual pieces of application logic in isolation, making it easier to cover more complex logic and edge cases.

**I'll use both.** Integration tests will cover the API behaviour, while unit tests will cover application logic that makes sense to test separately.

### Data Structure

I first chose to start by designing the database structure. 3 things must be stored separately:

- Locations
- Points of Interest (POI)
- Categories

Thinking about the best way of storing the categories I reached these 2 options:

- **Option 1: Two table design (no category table)**

    This would mean having a categories column (probably a JSON or text column) on the POI table. The only pro I see for this approach is simplicity. Cons would include being unable to effectively query by category without parsing text and schema changes would be harder in the future (such as adding a created_at field). It would limit future features, like filtering by category popularity.

- **Option 2: Three tables with a join table**

    Pros for this approach include query flexibility (being able to query for questions like show me all POIs of a specific category), data consistency (all category names live in one table, this means we can normalize data at the source, to avoid differences like "beach" and "Beach"), and future proofing (if in the future we want to add a created_at column or track which POIs most commonly use each category). Only con I see would be database overhead.

**I opted to go with option 2.** While option 1 would be simpler it would limit the future features this app could have.

### Database Schema

The migrations create 4 tables:

- `locations`, with a name, region and location_point
- `pois`, with a name, description and location_point
- `categories`, with a name
- `categories_pois`, which connects POIs and categories

I chose to keep locations, POIs and categories in separate tables. Categories are connected to POIs through a join table because both sides can have multiple related records. This also makes it easier to query POIs by category without storing and parsing a list of categories on the POI itself.

Names and regions use string because they are short values, while POI descriptions use text because they do not need an artificial length limit. The name and coordinate fields are required because a record without them would not be useful to the application.

Locations and POIs store their coordinates as `geometry(Point,4326)`. This keeps the coordinate data in a format PostGIS can use for spatial queries, such as finding nearby POIs.

#### Automatic Timestamps on All Models

I enabled Rails' automatic timestamps (`t.timestamps`) on all tables:

- locations, pois, categories - all get created_at and updated_at columns by default.

This tracks when records are created and last modified. While not explicitly required for this challenge, it's useful for audit trails and debugging data import issues. If I wanted to disable this for any table, I'd need to add timestamps: false to the migration.

### Storing Location Coordinates

Thinking about how to store coordinates I reached these 3 options:

- **Option 1: Text columns for latitude and longitude**

    Pros are being easy to export in simple formats like CSV or JSON, as well as working with any database system. Cons are being unable to use spatial queries, needing manual math (for distance calculations), and no special indexing (slow for finding nearby locations). This approach throws away the built-in spatial functions of PostGIS, so I'm not moving forward with it.

- **Option 2: GeoJSON text column**

    Pros are that this is a standard format that works with any mapping library (like Google Maps or Leaflet), and being easy to export/import in JSON API responses. Cons include having no native spatial functions (like option 1), and the database not recognizing this as a point, even though it contains coordinates.

- **Option 3: Native PostGIS geometry columns**

    Pros include removing manual math by using built-in spatial functions, GiST indexes (we can create GiST indexes to efficiently support spatial queries such as finding nearby POIs), and type safety (db validates that values are valid geometry points).

**I opted for option 3** because spatial queries are a core requirement, and PostGIS provides the appropriate data types, functions, and indexing for this use case.

### Preventing Duplicates

Next step is preventing duplicates while importing data, since the CSV structure may change. There are 2 options:

- **Option 1: Check existence before creating**

    This works but is slow for large files, hits the database once for every row.

- **Option 2: Upsert in batch with unique constraints**

    This is more efficient since it's a single SQL statement, that will either insert or update each row without creating duplicates. It's faster and handles everything automatically.

**I decided to go with option 2.**

For locations and categories I prevent duplicate entries by adding a unique index on their respective name fields, but for pois there's 2 options:

- **Option 1: Unique constraint on name**

    This would prevent multiple POIs with the same name regardless of location, which doesn't make sense - you could have "Beach" in Lagos and "Beach" in Sintra.

- **Option 2: Composite unique constraint on name + location_point**

    Pros include allowing different POIs to share names at different locations, and enabling unique identification by the combination of name and coordinates. Only con is slightly more complex SQL queries but negligible performance impact.

**I decided to go with option 2.** This allows "Beach" to exist in multiple cities while still preventing exact duplicates (same name at same location).

### Importing Data

I then started thinking about the best way to import data from the CSV files. There are 3 options:

- **Option 1: Rake task**

    Pros include having a clear separation of concerns (importing data is a separate task), and being easy to test. Cons would include being a bit overkill for quick local development.

- **Option 2: Seeds file**

    Pros are simplicity, a single file approach, as well as running a single command and loading everything. Cons are mixing 2 responsibilities (seeding vs importing external data) and being harder to test.

- **Option 3: Using a gem**

    Pros include having to write less code and handling easy to miss edge cases. Cons include adding a dependency (another thing to maintain and update), being a bit too much for simple structured CSV data, and having to learn a new library's API.

**I'll import the CSV files directly in db/seeds.rb** since these represent the initial dataset for the challenge. This keeps setup simple and allows running rails db:seed to populate the database immediately. I thought about using a rake task to enforce separation of concerns, but I think that would be overengineering for this case since these csv files are the initial data for the exercise.

#### Category Import from CSV

The POI CSV contains a comma-separated categories column, which is parsed during import:

1. Categories are extracted, deduplicated, and inserted into the categories table.
2. POIs are then associated with their categories via the join table.
3. If a category already exists, it's not duplicated.

This two step approach ensures data consistency while handling edge cases like empty or duplicate category names in the CSV.

### Import Error Handling

- **Option 1: Log and skip bad rows**

    This is the choice that makes sense when faulty data is expected.

- **Option 2: Transaction rollback**

    Pros include data consistency, but cons are that it will be slow for large datasets, and that we may need to re-import everything after failure. It's an all or nothing approach.

- **Option 3: Import after validation**

    With this option we first validate data, and only import it after ensuring the data is good. Pros are having clear failures (we can see exactly what's wrong before importing, and fix it), this also works towards good user experience. Cons include passing over data twice (slow for large files) and still having the all or nothing approach of option 2.

**I'll validate the CSV structure and content before importing.** This catches missing columns, invalid coordinates, and other issues before touching the database. For this small dataset, it's only a few extra lines of code and gives clear feedback about what needs fixing.

### API Structure

For the API, I considered whether to treat trip planning as a traditional resource or as an operation.

- **Option 1: Resource-based controllers**

    This would mean having controllers that map directly to database resources, such as LocationsController and PoisController. This fits Rails conventions well and makes the API endpoints easy to understand. Trip planning would still need a separate endpoint because a trip is not stored in the database.

- **Option 2: A single controller for the entire API**

    This would keep all endpoints in one place, but would mix responsibilities and make the controller harder to maintain as more functionality is added.

**I opted for separate controllers** based on the main API responsibilities. Locations and POIs are persisted resources, so they have their own controllers. Trip planning is an operation rather than a persisted resource, so it will have its own controller without requiring a Trip model.

### API Response Format

I considered whether the controllers should return HTML views or JSON responses.

- **Option 1: HTML views**

    This would allow Rails to render the frontend directly from controller actions. This could be useful if I decide to implement the frontend bonus using Rails views, but it would not directly satisfy the REST API requirement.

- **Option 2: JSON responses**

    This keeps the backend focused on providing the REST API and allows any frontend to consume the API independently. It also leaves the option of adding a Rails-based frontend later without changing the underlying data model.

**I opted for JSON responses** because the core requirement is a REST API. If I implement the frontend bonus later, I can add Rails views without changing the database structure or the API's underlying data.

### Error Handling

The API returns appropriate HTTP status codes for invalid requests and missing resources.

- **400 Bad Request:** invalid or missing request parameters.
- **404 Not Found:** the requested resource does not exist.

I considered how to structure error responses for invalid requests and missing resources. There are 2 options:

- **Option 1: Include full exception details**

    This would expose internal implementation details like model names and stack traces, which could be a security risk in production.

- **Option 2: Simplified error messages with just the resource name (for 404) or generic error field (for validation errors)**

    Pros include hiding internal implementation details, cleaner responses for frontend consumption, and easier to customize per error type. Cons would be less detailed debugging information during development.

**I opted for option 2.** The API returns `{ "error": "<message>" }` for validation errors and `{ "error": "<Model> not found" }` for missing resources. This keeps responses clean while still providing actionable feedback.

### Locations

I will start by implementing the Locations before the more complex POI and trip planning endpoints. Locations are a relatively simple resource and this provides a way to establish the structure and response format before implementing the more complex spatial queries.

The API will initially support:

- `GET /locations` to browse available locations, with an optional name filter
- `GET /locations/:id` to view a specific location

### Categories

The only endpoint I'll do for now is:

- `GET /categories` to fetch all categories

I'm creating this endpoint just so that a future frontend may fetch it for filtering purposes, instead of hardcoding them.

### POIs

I will implement the POI endpoints after Locations and Categories. POIs are more complex because they have categories and geographic coordinates.

The API will support:

- `GET /pois` to browse available POIs, with optional name and category filter
- `GET /pois/:id` to view a specific POI

### POI Response Consistency

All endpoints return POIs using the same response structure, including categories.

This keeps the API consistent and allows the Poi schema to be reused across endpoints.

### API Coordinate Response

I considered how to return coordinates in the API. There are 2 options:

- **Option 1: Return the PostGIS point**

    This avoids conversion but exposes the database representation to API consumers.

- **Option 2: Return separate latitude and longitude fields**

    This is simpler for API consumers and keeps the database representation internal.

**I opted for option 2.** The API returns latitude and longitude while PostGIS geometry is used internally for spatial queries.

### Trip Planning

This is the most complex part of the API because it needs to use the geographic coordinates of the origin, destination, and POIs to determine which POIs are along the route and return them in order.

The API will support:

- `GET /trip-planning` to plan a route between an origin and destination, returning the requested number of POIs along the route, with an optional category filter

The challenge does not define exactly how to decide whether a POI is along the route, or how to choose the requested number when there are more POIs available. I will make these choices based on keeping the implementation simple while still making the result useful.

#### Determining whether a POI is along the route

There are a few possible approaches:

- **Option 1: Straight-line route + threshold**

    Consider a POI part of the route if it is within a certain distance of the line. This is simple and can be handled entirely with PostGIS.

- **Option 2: Actual driving route**

    Use a routing service to calculate the road route and find POIs near it. This would be more realistic, but adds an external dependency and more complexity.

**I will use the straight line with a distance threshold.** It keeps the implementation self-contained and is sufficient for the scope of this challenge.

The route is defined by the origin and destination. I will keep this route fixed when evaluating and ordering POIs rather than recalculating it after each selected POI. Recalculating the route after each stop would turn the problem into planning a sequence of intermediate stops, which is beyond the scope of the challenge.

#### Distance threshold

The challenge does not define a distance threshold for determining whether a POI is along the route. I considered deriving the threshold from the distance between POIs and the provided locations, but the POIs are not explicitly associated with a location and some are intentionally distributed far beyond the nearest listed location. Using the furthest such distance would therefore make the route corridor unnecessarily broad.

Instead, I will use a fixed **10 km threshold** based on the geographic distribution of the provided dataset. This provides a reasonable tolerance for considering a POI to be along a trip without including POIs that are significantly off the route.

The same threshold is applied to the fixed origin-to-destination line for each trip.

#### Service object structure

The trip planning logic will be handled by a dedicated service because it contains enough application logic to keep it out of the controller.

There are a few ways I could structure the trip planning service:

- **Option 1: Use an instance with initialize to store the origin, destination, category, and number of POIs, then call plan.**

- **Option 2: Use plan as a class method and pass everything it needs directly to it.**

Option 1 makes more sense when the service needs to keep state or dependencies that are shared across several operations. Option 2 is simpler when the operation is stateless and everything it needs is provided as input.

**I will use Option 2** because trip planning is currently a single stateless operation. There is no useful state that needs to be stored between method calls, so creating a service instance just to call `plan` would add unnecessary structure.

#### Selecting the requested POIs

If more POIs are available than requested, there are a few options:

- **Option 1: Return the ones closest to the origin.**

- **Option 2: Return the ones closest to the destination.**

- **Option 3: Spread them across the route.**

The first two are simple, but can result in all the stops being concentrated in one part of the trip. I will instead spread the selected POIs across the route, choosing them at roughly even intervals.

Regarding how to spread them there are 2 options:

- **Option 1: Select POIs at roughly even positions in the ordered list.**

- **Option 2: Divide the route into sections and select POIs based on their geographic position along the route.**

**I will use Option 1** because it keeps the implementation simple while still spreading the selected POIs across the route. This is an approximation rather than a true geographic distribution: if several POIs are clustered together, they can still be closer to each other than the selected positions suggest. If I still have time after doing the bonus I think I'll revisit this.

The category filter will be applied before selecting the POIs, so only matching POIs are considered.

If fewer POIs are available than requested, I will return all matching POIs.

### Find Nearest POI

The API will support:

- `GET /pois/nearest` to find the closest POI to a given latitude and longitude

There are a couple of ways to structure the endpoint:

- **Option 1: Add nearest to PoisController as a collection action.**

- **Option 2: Create a separate controller for the endpoint.**

**I will use Option 1** because the endpoint is still operating on the POI collection. A separate controller would add unnecessary structure.

For the implementation, there are also two options:

- **Option 1: Keep the query in PoisController.**

- **Option 2: Create a separate service for finding the nearest POI.**

**I will use Option 1** because the logic is simple: validate the coordinates and run a single PostGIS query. A service would be a bit overkill for this operation.

The distance will be calculated using PostGIS rather than in Ruby.

### Pagination

I added pagination to `/locations`, `/categories` and `/pois` since these are collection endpoints and could contain a large number of records. These endpoints are paginated by default, using a default page and page size.

For `/trip-planning`, I considered 2 options:

- **Option 1: Do not paginate**

    This keeps the endpoint simple and allows the frontend to receive all the POIs selected for the trip in a single response.

- **Option 2: Paginate**

    This would make the endpoint behave more like the other collection endpoints, but could require multiple requests when the frontend needs all the POIs for the map.

**I decided to use a middle ground:** `/trip-planning` is not paginated by default, but supports pagination when `page` or `per_page` is provided. This allows the map to receive all selected POIs by default, while still supporting paginated results when needed.

I'll be applying the pagination in Ruby after the trip-planning query has selected and ordered the POIs. This keeps the route selection and ordering deterministic before pagination is applied.

### CI/CD

This project uses GitHub Actions for continuous integration. The workflow runs on every push and pull request, and consists of three steps:

1. **Build** the test Docker image (`docker compose build test`), ensuring the image used for linting and testing reflects the current `Gemfile.lock` and Dockerfile.
2. **Lint** the codebase with RuboCop (`docker compose --profile test run --rm --no-deps test bundle exec rubocop`), run without the `db` service dependency since linting doesn't require a database connection.
3. **Test** the application (`docker compose --profile test run --rm test`), running the full RSpec suite against a PostgreSQL/PostGIS database.

The workflow definition lives at `.github/workflows/ci.yml`.

### Running the same checks locally

To reproduce the CI pipeline on your machine before pushing:

```bash
docker compose build test
docker compose --profile test run --rm --no-deps test bundle exec rubocop
docker compose --profile test run --rm test
```

### Frontend

Since the frontend is a bonus, I wanted to keep it simple and avoid adding unnecessary infrastructure.

I considered two options:

- **Option 1: Separate frontend application**

    This could use React and communicate with the Rails API, but would add another application, dependencies, build system and Docker service.

- **Option 2: Rails-based frontend**

    Rails can render the frontend using its existing view layer, keeping everything in one application.

**I opted for option 2** because I want to learn a different skill, and I'm already familiar with JavaScript frontend frameworks. It is also enough for the scope of the bonus.

I then considered two ways for the frontend to get data:

- **Option 1: Use a Rails controller directly**

    The controller could access the models and services and pass the data to the view.

- **Option 2: Consume the existing REST API**

    The frontend can call the existing API endpoints and use their responses.

**I opted for option 2** because the API already provides the functionality the frontend needs, so there is no need to duplicate it in another controller. It also means the frontend uses the same interface that any other client would use.

The frontend will only use the endpoints it needs, such as `/locations`, `/categories` and `/trip-planning`. Endpoints such as `/pois/nearest` remain available as API functionality but are not needed for the frontend.

#### JavaScript vs TypeScript

I considered two options for the frontend language:

- **Option 1: TypeScript**

    This would provide type safety, but would require additional tooling and configuration.

- **Option 2: JavaScript**

    This is already enough for the scope of the frontend and does not require additional tooling.

**I opted for option 2** because the frontend is a small bonus feature, so I don't think the additional setup and complexity of TypeScript is justified for this project.

#### Frontend Technologies

The frontend uses:

- Rails Views
- JavaScript
- Importmap
- Propshaft
- Leaflet
- OpenStreetMap
- OSRM

#### Frontend Structure

I considered whether to split the JavaScript into multiple files.

- **Option 1: Multiple JavaScript files**

    This would separate responsibilities such as API requests, map handling and UI rendering. This would make each file smaller, but would add more structure and imports.

- **Option 2: One JavaScript file**

    This keeps the frontend simple and makes the whole flow easy to follow in one place. The downside is that the file could become harder to maintain if the frontend grows significantly.

**I opted for option 2** because the frontend is small enough that splitting it into multiple files would add more complexity than value.

#### Map

I considered a few options for displaying the map:

- **Option 1: Google Maps**

    This is a mature mapping platform with routing support, but requires an API key and adds a dependency on Google's services.

- **Option 2: Mapbox**

    This provides maps and routing, but also requires an API key and adds another external service.

- **Option 3: Leaflet with OpenStreetMap**

    Leaflet is a lightweight mapping library and OpenStreetMap provides the map data. This gives me the functionality needed without adding a large frontend dependency.

**I opted for option 3** because it is simple, open source and works well with the existing Rails frontend.

#### Map Markers

I considered two options:

- **Option 1: Leaflet default markers**

    This would be simpler, but all points would look the same.

- **Option 2: Custom Leaflet markers**

    Leaflet's `divIcon` allows the markers to be created with HTML and styled with CSS. This also allows POI numbers to be displayed directly on the map.

**I opted for option 2** because it makes the different types of points easier to identify.

The markers use:

- Green for the origin
- Red for the destination
- Blue numbered markers for POIs

#### Route Display

- **Option 1: Straight lines**

    This is simple and does not require an external routing service. The downside is that a straight line does not represent the route a vehicle would actually take.

- **Option 2: Route following roads**

    A routing service can calculate a driving route between the origin, POIs and destination. This gives a more realistic representation of the trip, but adds an external dependency.

**I opted for option 2** because the frontend is intended to represent a roadtrip, so showing the actual driving route is more useful than showing straight lines between points.

#### Routing Service

For calculating the driving route I considered:

- **Option 1: OSRM**

    Open-source routing engine that supports driving routes and multiple waypoints. It can return the route as GeoJSON, which can be displayed directly by Leaflet.

- **Option 2: GraphHopper**

    Provides routing and additional features, but adds another external service and API configuration.

- **Option 3: OpenRouteService**

    Provides routing using OpenStreetMap data, but also requires external API configuration.

**I opted for option 1** because OSRM provides the functionality needed for this challenge with minimal setup.

The frontend sends the origin, selected POIs and destination to OSRM. The returned road geometry is then displayed using Leaflet.

#### Trip Planning vs Route Display

The backend and frontend use the route for different purposes.

The backend uses the straight origin-to-destination line and the 10 km threshold to decide which POIs are along the trip.

The frontend uses OSRM to display the resulting trip as an actual driving route.

I chose to keep these separate because changing the backend POI selection to use a routing service would make the trip-planning algorithm more complex and introduce an external dependency into the API.

#### POI Panel

I wanted the selected POIs to be visible without requiring the user to click each map marker.

I considered two options:

- **Option 1: Show POIs only on the map**

    This keeps the interface smaller, but the user needs to interact with the markers to see the POI information.

- **Option 2: Show POIs in a panel next to the map**

    This allows the user to see the POIs, categories and descriptions at the same time as the map.

**I opted for option 2** because the map provides the geographic information while the panel provides the detailed information.

The POIs are displayed in route order and numbered to match their markers on the map. Clicking a POI in the panel focuses its marker and opens its popup.

#### Map and Panel Layout

I considered placing the POI panel above or below the map, but decided to place it beside the map on larger screens.

This allows the user to see the route and the POI information at the same time.

On smaller screens the layout changes to a single column, with the map above the POI panel.

#### Frontend Dependencies

I wanted to avoid adding dependencies where the existing Rails setup was enough.

The frontend therefore uses:

- **Leaflet** for the interactive map
- **OpenStreetMap** for map tiles
- **OSRM** for driving route calculation

No frontend framework or additional marker library is used.

Leaflet is loaded through Importmap and the frontend assets are served through Propshaft.

#### Documentation

The planner has buttons for the README and Swagger. Both have a back button to return to the planner.

#### README Rendering

I considered two options:

- **Option 1: Display the raw README**

    This requires no processing, but the Markdown would not be formatted.

- **Option 2: Render the README as HTML**

    Redcarpet converts the existing `README.md` into HTML which is then rendered in a Rails view.

**I opted for option 2** because Redcarpet is already a dependency. Also it looks a lot better.

### Refactoring

#### Selecting the requested POIs

After finishing the frontend bonus, I noticed that the selected POIs were often clustered around the origin and destination. This is because the dataset has many more POIs near the locations than in the middle of the route, so evenly spacing them in the ordered list does not produce an even geographic distribution.

I considered 2 options:

- **Option 1: Select evenly spaced POIs from the ordered list**

    This is simple, but does not account for how POIs are distributed geographically.

- **Option 2: Divide the route into sections and select POIs based on their position along the route**

    This distributes POIs based on the route rather than the number of POIs in each area. Some sections may not contain any POIs.

**I opted for option 2** because I want the selected POIs to be spread across the trip.

The route position is represented between `0.0` and `1.0`, where `0.0` is the origin and `1.0` is the destination. I divide this range into as many buckets as the requested number of POIs and try to select one POI from each bucket.

For example, requesting 4 POIs creates 4 sections:

```text
Origin                                      Destination
  |------------|------------|------------|------------|
       POI 1         POI 2        POI 3        POI 4
```

When a bucket contains multiple POIs, I select the one closest to its centre.

If a bucket is empty, I fill the remaining slots with unused POIs that are furthest from the POIs already selected. This helps maximise the geographic spread.

The category filter is applied before selection, so only matching POIs are considered.

If fewer POIs are available than requested, I return all matching POIs.
