# frozen_string_literal: true

module Api
  class LocationsController < BaseController
    before_action :validate_pagination, only: :index

    def index
      locations = Location.all
      locations = locations.name_matches(params[:name]) if params[:name].present?

      total = locations.count
      page, per_page = pagination_params

      locations = locations
                  .order(:id)
                  .limit(per_page)
                  .offset((page - 1) * per_page)

      render json: {
        locations: locations.as_json(
          except: :location_point,
          methods: %i[latitude longitude]
        ),
        pagination: pagination_metadata(page, per_page, total)
      }
    end

    def show
      location = Location.find(params[:id])

      render json: location.as_json(
        except: :location_point,
        methods: %i[latitude longitude]
      )
    end
  end
end
