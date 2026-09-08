# frozen_string_literal: true

class TripPlanning
  # Maximum distance (in meters) from origin to destination line for a POI to be considered along the route
  ROUTE_THRESHOLD_METERS = 10_000

  def self.plan(origin:, destination:, number_of_pois:, categories: [])
    pois = pois_along_route(origin, destination)
    pois = pois.with_categories(categories.map(&:id)) if categories.any?

    select_pois(pois, number_of_pois)
  end

  # Returns all POIs within the threshold of the straight line between origin and destination.
  def self.pois_along_route(origin, destination)
    route_position = route_position_sql(origin, destination)

    Poi
      .includes(:categories)
      .select(
        'pois.*',
        Arel.sql("#{route_position} AS route_position")
      )
      .where(
        route_distance_sql(origin, destination),
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
    return [pois.first] if number_of_pois == 1

    selected = select_from_buckets(pois, number_of_pois)
    fill_remaining_pois(selected, pois, number_of_pois)

    selected.sort_by { |poi| poi.route_position.to_f }
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
  # A value of 0.0 means at the origin, 1.0 at the destination.
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

  def self.select_from_buckets(pois, number_of_pois)
    buckets = Array.new(number_of_pois) { [] }

    pois.each do |poi|
      bucket = [
        (poi.route_position.to_f * number_of_pois).floor,
        number_of_pois - 1
      ].min

      buckets[bucket] << poi
    end

    buckets.filter_map.with_index do |bucket, index|
      next if bucket.empty?

      target = (index + 0.5) / number_of_pois

      bucket.min_by do |poi|
        (poi.route_position.to_f - target).abs
      end
    end
  end

  def self.fill_remaining_pois(selected, pois, number_of_pois)
    remaining = pois - selected

    while selected.length < number_of_pois && remaining.any?
      poi = remaining.max_by do |candidate|
        selected.map do |selected_poi|
          (candidate.route_position.to_f - selected_poi.route_position.to_f).abs
        end.min
      end

      selected << poi
      remaining.delete(poi)
    end
  end

  private_class_method :pois_along_route,
                       :select_pois,
                       :route_distance_sql,
                       :route_position_sql,
                       :select_from_buckets,
                       :fill_remaining_pois
end
