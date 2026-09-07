class TripPlanning
  # Maximum distance (in meters) from origin to destination line for a POI to be considered along the route
  ROUTE_THRESHOLD_METERS = 10_000

  def self.plan(origin:, destination:, number_of_pois:, category: nil)
    pois = pois_along_route(origin, destination)
    pois = pois.with_category(category.id) if category

    select_pois(pois, number_of_pois)
  end

  # Returns all POIs within the threshold of the straight line between origin and destination.
  def self.pois_along_route(origin, destination)
    Poi
      .includes(:categories)
      .where(
        route_distance_sql(origin, destination),
        ROUTE_THRESHOLD_METERS
      )
      .order(
        Arel.sql(
          "#{route_position_sql(origin, destination)} ASC, pois.id ASC"
        )
      )
  end

  # Select a subset of POIs at even intervals along the route.
  def self.select_pois(pois, number_of_pois)
    pois = pois.to_a
    return pois.to_a if pois.length <= number_of_pois
    return [pois.first] if number_of_pois == 1

    last_index = pois.length - 1

    number_of_pois.times.map do |index|
      position = (index * last_index.to_f / (number_of_pois - 1)).round
      pois[position]
    end
  end

  # Generate SQL to check if a POI is within the threshold of the line.
  def self.route_distance_sql(origin, destination)
    ApplicationRecord.sanitize_sql_array(
      [
        <<~SQL.squish,
          ST_DWithin(
            location_point::geography,
            ST_MakeLine(
              ST_SetSRID(ST_MakePoint(?, ?), 4326),
              ST_SetSRID(ST_MakePoint(?, ?), 4326)
            )::geography,
            ?
          )
        SQL
        origin.location_point.x,
        origin.location_point.y,
        destination.location_point.x,
        destination.location_point.y,
        ROUTE_THRESHOLD_METERS
      ]
    )
  end

  # Generate SQL to calculate the normalized position of a POI along the route.
  # A value of 0.0 means at the origin, 1.0 means at the destination.
  def self.route_position_sql(origin, destination)
    ApplicationRecord.sanitize_sql_array(
      [
        <<~SQL.squish,
          ST_LineLocatePoint(
            ST_MakeLine(
              ST_SetSRID(ST_MakePoint(?, ?), 4326),
              ST_SetSRID(ST_MakePoint(?, ?), 4326)
            ),
            location_point
          )
        SQL
        origin.location_point.x,
        origin.location_point.y,
        destination.location_point.x,
        destination.location_point.y
      ]
    )
  end

  private_class_method :pois_along_route,
                       :select_pois,
                       :route_distance_sql,
                       :route_position_sql
end
