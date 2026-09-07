class LocationsController < ApplicationController
  def index
    locations = Location.all
    locations = locations.name_matches(params[:name]) if params[:name].present?

    render json: locations.as_json(
      except: :location_point,
      methods: %i[latitude longitude],
    )
  end

  def show
    location = Location.find(params[:id])

    render json: location.as_json(
      except: :location_point,
      methods: %i[latitude longitude],
    )
  end
end
