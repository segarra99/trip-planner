# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RoutingService do
  let(:factory) { RGeo::Geographic.spherical_factory(srid: 4326) }

  let(:origin) do
    Location.new(
      name: 'Lisboa',
      region: 'Lisboa',
      location_point: factory.point(-9.1393, 38.7223)
    )
  end

  let(:destination) do
    Location.new(
      name: 'Porto',
      region: 'Porto',
      location_point: factory.point(-8.6291, 41.1579)
    )
  end

  let(:route_geometry) do
    {
      'type' => 'LineString',
      'coordinates' => [
        [-9.1393, 38.7223],
        [-9.0, 39.5],
        [-8.8, 40.3],
        [-8.6291, 41.1579]
      ]
    }
  end

  let(:response_body) do
    {
      'code' => 'Ok',
      'routes' => [
        {
          'geometry' => route_geometry
        }
      ]
    }.to_json
  end

  def http_response(
    body,
    response_class: Net::HTTPOK,
    code: '200',
    message: 'OK'
  )
    response = response_class.new('1.1', code, message)
    response.instance_variable_set(:@body, body)
    response.instance_variable_set(:@read, true)
    response
  end

  describe '.route' do
    before do
      allow(described_class)
        .to receive(:request)
        .and_return(http_response(response_body))
    end

    it 'returns the route geometry from the routing service' do
      result = described_class.route(
        origin: origin,
        destination: destination
      )

      expect(result).to eq(route_geometry)
    end

    it 'builds the request using the origin and destination coordinates' do
      expected_uri = URI.parse(
        'https://router.project-osrm.org/route/v1/driving/' \
        '-9.1393,38.7223;-8.6291,41.1579' \
        '?overview=full&geometries=geojson'
      )

      expect(
        described_class.send(
          :route_uri,
          origin,
          destination
        )
      ).to eq(expected_uri)
    end

    it 'raises RoutingError when the response is invalid JSON' do
      allow(described_class)
        .to receive(:request)
        .and_return(http_response('invalid json'))

      expect do
        described_class.route(
          origin: origin,
          destination: destination
        )
      end.to raise_error(
        RoutingService::RoutingError,
        'Invalid response from routing service.'
      )
    end

    it 'raises RoutingError when no route is returned' do
      response = {
        'code' => 'Ok',
        'routes' => []
      }.to_json

      allow(described_class)
        .to receive(:request)
        .and_return(http_response(response))

      expect do
        described_class.route(
          origin: origin,
          destination: destination
        )
      end.to raise_error(
        RoutingService::RoutingError,
        'No driving route could be found.'
      )
    end

    it 'raises RoutingError when the routing service returns a non-Ok code' do
      response = {
        'code' => 'NoRoute',
        'routes' => []
      }.to_json

      allow(described_class)
        .to receive(:request)
        .and_return(http_response(response))

      expect do
        described_class.route(
          origin: origin,
          destination: destination
        )
      end.to raise_error(
        RoutingService::RoutingError,
        'No driving route could be found.'
      )
    end

    it 'raises RoutingError when the routing service cannot be reached' do
      allow(described_class)
        .to receive(:request)
        .and_raise(SocketError)

      expect do
        described_class.route(
          origin: origin,
          destination: destination
        )
      end.to raise_error(
        RoutingService::RoutingError,
        'Unable to connect to routing service.'
      )
    end
  end

  describe '.request' do
    it 'returns a successful HTTP response' do
      response = http_response(response_body)

      allow(Net::HTTP)
        .to receive(:get_response)
        .and_return(response)

      result = described_class.send(
        :request,
        origin,
        destination
      )

      expect(result).to eq(response)
    end

    it 'raises RoutingError when the HTTP response is unsuccessful' do
      response = http_response(
        '',
        response_class: Net::HTTPNotFound,
        code: '404',
        message: 'Not Found'
      )

      allow(Net::HTTP)
        .to receive(:get_response)
        .and_return(response)

      expect do
        described_class.send(
          :request,
          origin,
          destination
        )
      end.to raise_error(
        RoutingService::RoutingError,
        'Unable to calculate the driving route.'
      )
    end
  end
end
