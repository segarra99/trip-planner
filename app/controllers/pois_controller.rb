class PoisController < ApplicationController
  before_action :validate_coordinates, only: :nearest

  def index
    pois = Poi.all
    pois = pois.name_matches(params[:name]) if params[:name].present?
    pois = pois.with_category(params[:category]) if params[:category].present?

    render json: pois.as_json(
      except: :location_point,
      methods: %i[latitude longitude],
      include: :categories
    )
  end

  def show
    poi = Poi.find(params[:id])

    render json: poi.as_json(
      except: :location_point,
      methods: %i[latitude longitude],
      include: :categories
    )
  end

  def nearest
    point_sql = ApplicationRecord.sanitize_sql_array(
      [
        'ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography',
        Float(params[:lng]),
        Float(params[:lat])
      ]
    )

    poi = Poi
          .order(
            Arel.sql("location_point::geography <-> #{point_sql}")
          )
          .first

    render json: poi.as_json(
      except: :location_point,
      methods: %i[latitude longitude],
      include: :categories
    )
  end

  private

  def validate_coordinates
    lat = Float(params[:lat], exception: false)
    lng = Float(params[:lng], exception: false)

    return if lat && lng && lat.between?(-90, 90) && lng.between?(-180, 180)

    render json: { error: 'valid lat and lng are required' }, status: :bad_request
  end
end
