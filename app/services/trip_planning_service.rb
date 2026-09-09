# frozen_string_literal: true

class TripPlanningService
  # Maximum distance in meters from the driving route for a POI to be considered along the route.
  ROUTE_THRESHOLD_METERS = 20_000

  # Portion of the route used for evenly distributing selected POIs.
  # Avoid selecting stops immediately at the origin or destination.
  ROUTE_SELECTION_START = 0.2
  ROUTE_SELECTION_END = 0.8

  def self.plan(origin:, destination:, number_of_pois:, categories: [])
    route = route_for(origin, destination)

    pois = pois_along_route(route)

    if categories.any?
      category_ids = categories.map(&:id)
      pois = pois.where(
        id: Poi.with_categories(category_ids).select(:id)
      )
    end

    select_pois(pois, number_of_pois)
  end

  # Returns the road route when routing succeeds.
  # Falls back to a straight line when the routing service fails.
  def self.route_for(origin, destination)
    RoutingService.route(
      origin: origin,
      destination: destination
    )
  rescue RoutingService::RoutingError => e
    Rails.logger.warn(
      "Routing failed: #{e.message}. Falling back to straight-line route."
    )

    straight_line_route(origin, destination)
  end

  # Returns POIs within the threshold of the actual driving route.
  def self.pois_along_route(route)
    route_position = route_position_sql(route)

    Poi
      .preload(:categories)
      .select(
        'pois.*',
        Arel.sql("#{route_position} AS route_position")
      )
      .where(
        route_distance_sql(route),
        ROUTE_THRESHOLD_METERS
      )
      .order(
        Arel.sql('route_position ASC, pois.id ASC')
      )
  end

  # Select POIs spread across the route.
  def self.select_pois(pois, number_of_pois)
    pois = pois.to_a

    return pois if pois.length <= number_of_pois

    selected = select_from_buckets(pois, number_of_pois)
    fill_remaining_pois(selected, pois, number_of_pois)

    selected.sort_by { |poi| poi.route_position.to_f }
  end

  # Generate SQL to check if a POI is within the threshold of the actual driving route.
  def self.route_distance_sql(route)
    geometry_sql = route_geometry_sql(route)

    ApplicationRecord.sanitize_sql_array(
      [
        <<~SQL.squish,
          ST_DWithin(
            location_point::geography,
            #{geometry_sql}::geography,
            ?
          )
        SQL
        ROUTE_THRESHOLD_METERS
      ]
    )
  end

  # Generate SQL to calculate the normalized position of a POI along the route.
  # 0.0 = beginning of route
  # 1.0 = end of route
  def self.route_position_sql(route)
    geometry_sql = route_geometry_sql(route)

    <<~SQL.squish
      ST_LineLocatePoint(
        #{geometry_sql},
        location_point
      )
    SQL
  end

  # Converts the GeoJSON route returned by the routing service into a PostGIS geometry with SRID 4326.
  def self.route_geometry_sql(route)
    ApplicationRecord.sanitize_sql_array(
      [
        'ST_SetSRID(ST_GeomFromGeoJSON(?), 4326)',
        route.to_json
      ]
    )
  end

  # Builds a GeoJSON LineString connecting the origin directly to the destination.
  # This route is used only when the external routing service fails.
  def self.straight_line_route(origin, destination)
    {
      'type' => 'LineString',
      'coordinates' => [
        [origin.location_point.x, origin.location_point.y],
        [destination.location_point.x, destination.location_point.y]
      ]
    }
  end

  # Divides the usable portion of the route into buckets and selects the POI closest to the target position.
  def self.select_from_buckets(pois, number_of_pois)
    buckets = Array.new(number_of_pois) { [] }

    pois.each do |poi|
      bucket = bucket_for(poi.route_position.to_f, number_of_pois)
      buckets[bucket] << poi if bucket
    end

    buckets.filter_map.with_index do |bucket, index|
      next if bucket.empty?

      target = bucket_target(index, number_of_pois)
      bucket.min_by { |poi| (poi.route_position.to_f - target).abs }
    end
  end

  def self.bucket_for(position, number_of_pois)
    return unless position.between?(ROUTE_SELECTION_START, ROUTE_SELECTION_END)

    usable_length = ROUTE_SELECTION_END - ROUTE_SELECTION_START

    ((position - ROUTE_SELECTION_START) / usable_length * number_of_pois)
      .floor
      .clamp(0, number_of_pois - 1)
  end

  def self.bucket_target(index, number_of_pois)
    usable_length = ROUTE_SELECTION_END - ROUTE_SELECTION_START

    ROUTE_SELECTION_START +
      ((index + 0.5) / number_of_pois) * usable_length
  end

  # Fills any remaining POI slots after bucket selection.
  # Each additional POI is chosen based on the largest minimum distance
  # from the POIs that have already been selected, helping spread results
  # across the route instead of clustering them together.
  def self.fill_remaining_pois(selected, pois, number_of_pois)
    remaining = pois - selected

    while selected.length < number_of_pois && remaining.any?
      poi = if selected.empty?
              remaining.min_by do |candidate|
                (candidate.route_position.to_f - 0.5).abs
              end
            else
              remaining.max_by do |candidate|
                selected.map do |selected_poi|
                  (candidate.route_position.to_f - selected_poi.route_position.to_f).abs
                end.min
              end
            end

      selected << poi
      remaining.delete(poi)
    end
  end

  private_class_method :route_for,
                       :pois_along_route,
                       :select_pois,
                       :route_distance_sql,
                       :route_position_sql,
                       :route_geometry_sql,
                       :straight_line_route,
                       :select_from_buckets,
                       :bucket_for,
                       :bucket_target,
                       :fill_remaining_pois
end
