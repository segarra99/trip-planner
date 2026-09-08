# frozen_string_literal: true

module Api
  class TripPlanningController < BaseController
    before_action :validate_params, only: :index

    def index
      origin = Location.find(params[:origin])
      destination = Location.find(params[:destination])
      category = Category.find(params[:category]) if params[:category]

      pois = TripPlanning.plan(
        origin: origin,
        destination: destination,
        number_of_pois: params[:number_of_pois].to_i,
        category: category
      )

      return render_paginated(pois) if pagination_requested?

      render json: pois_json(pois)
    end

    private

    def pagination_requested?
      params[:page].present? || params[:per_page].present?
    end

    def render_paginated(pois)
      page, per_page = pagination_params
      total = pois.length

      pois = pois.drop((page - 1) * per_page).first(per_page)

      render json: {
        pois: pois_json(pois),
        pagination: pagination_metadata(page, per_page, total)
      }
    end

    def pois_json(pois)
      pois.as_json(
        except: :location_point,
        methods: %i[latitude longitude],
        include: :categories
      )
    end

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
end
