class TripPlanningController < ApplicationController
  before_action :validate_params, only: :plan

  def plan
    origin = Location.find(params[:origin])
    destination = Location.find(params[:destination])
    category = Category.find(params[:category]) if params[:category]

    pois = TripPlanning.plan(
      origin: origin,
      destination: destination,
      number_of_pois: params[:number_of_pois].to_i,
      category: category
    )

    render json: pois
  end

  private

  def validate_params
    required_params = %i[origin destination number_of_pois]

    return if required_params.all? { |param| params[param].present? }

    render json: { error: 'origin, destination and number of pois are required' },
           status: :bad_request
  end
end
