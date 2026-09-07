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

    render json: pois.as_json(
      except: :location_point,
      methods: %i[latitude longitude],
      include: :categories
    )
  end

  private

  def validate_params
    required_params = %i[origin destination number_of_pois]

    unless required_params.all? { |param| params[param].present? }
      return render json: { error: 'origin, destination and number of pois are required' },
                    status: :bad_request
    end

    number_of_pois = Integer(params[:number_of_pois], exception: false)

    return if number_of_pois&.positive?

    render json: { error: 'number_of_pois must be a positive integer' },
           status: :bad_request
  end
end
