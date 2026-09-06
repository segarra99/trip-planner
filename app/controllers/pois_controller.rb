class PoisController < ActionController::API
  before_action :validate_coordinates, only: :nearest

  def index
    pois = Poi.all
    pois = pois.name_matches(params[:name]) if params[:name].present?
    pois = pois.with_category(params[:category]) if params[:category].present?

    render json: pois.as_json(include: :categories)
  end

  def show
    poi = Poi.find(params[:id])

    render json: poi.as_json(include: :categories)
  end

  def nearest
    poi = Poi
          .order(
            Arel.sql(
              ApplicationRecord.sanitize_sql_array(
                [
                  <<~SQL.squish,
                    ST_Distance(
                      location_point::geography,
                      ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography
                    )
                  SQL
                  params[:lng].to_f,
                  params[:lat].to_f
                ]
              )
            )
          )
          .first

    render json: poi
  end

  private

  def validate_coordinates
    lat = params[:lat].to_f
    lng = params[:lng].to_f

    return if params[:lat].present? &&
              params[:lng].present? &&
              lat.between?(-90, 90) &&
              lng.between?(-180, 180)

    render json: { error: 'valid lat and lng are required' }, status: :bad_request
  end
end
