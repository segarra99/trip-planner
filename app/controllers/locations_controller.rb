class LocationsController < ActionController::API
  def index
    locations = Location.all
    locations = locations.name_matches(params[:name]) if params[:name].present?

    render json: locations
  end

  def show
    location = Location.find(params[:id])

    render json: location
  end
end
