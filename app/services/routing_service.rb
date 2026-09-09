# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

class RoutingService
  # Raised when the external routing service cannot provide a valid route.
  class RoutingError < StandardError
  end

  # Returns the driving route between two locations as a GeoJSON geometry.
  # Returned geometry is a GeoJSON LineString that can be consumed directly by PostGIS.
  def self.route(origin:, destination:)
    response = request(origin, destination)
    data = JSON.parse(response.body)

    validate_response(data)

    data['routes'].first['geometry']
  rescue JSON::ParserError
    raise RoutingError, 'Invalid response from routing service.'
  rescue SocketError, Timeout::Error, Errno::ECONNREFUSED
    raise RoutingError, 'Unable to connect to routing service.'
  end

  # Builds and executes the HTTP request against the OSRM routing API.
  def self.request(origin, destination)
    response = Net::HTTP.get_response(
      route_uri(origin, destination)
    )

    return response if response.is_a?(Net::HTTPSuccess)

    raise RoutingError, 'Unable to calculate the driving route.'
  end

  def self.route_uri(origin, destination)
    coordinates = [
      coordinate(origin),
      coordinate(destination)
    ].join(';')

    URI.parse(
      "https://router.project-osrm.org/route/v1/driving/#{coordinates}" \
      '?overview=full&geometries=geojson'
    )
  end

  def self.coordinate(location)
    "#{location.location_point.x},#{location.location_point.y}"
  end

  # Parses the OSRM response body and raises a routing error for invalid responses.
  def self.validate_response(data)
    return if data['code'] == 'Ok' && data['routes']&.any?

    raise RoutingError, 'No driving route could be found.'
  end

  private_class_method :request,
                       :route_uri,
                       :coordinate,
                       :validate_response
end
