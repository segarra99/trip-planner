# frozen_string_literal: true

module Api
  class BaseController < ActionController::API
    DEFAULT_PAGE = 1
    DEFAULT_PER_PAGE = 10

    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

    private

    def render_not_found(exception)
      render json: { error: "#{exception.model} not found" }, status: :not_found
    end

    # Serializes a location or collection of locations for API responses.
    def location_json(location_or_collection)
      location_or_collection.as_json(
        except: :location_point,
        methods: %i[latitude longitude]
      )
    end

    # Serializes a POI or collection of POIs for API responses.
    def poi_json(poi_or_collection)
      poi_or_collection.as_json(
        except: :location_point,
        methods: %i[latitude longitude],
        include: :categories
      )
    end

    def pagination_params
      [
        params.fetch(:page, DEFAULT_PAGE).to_i,
        params.fetch(:per_page, DEFAULT_PER_PAGE).to_i
      ]
    end

    def pagination_metadata(page, per_page, total)
      {
        page: page,
        per_page: per_page,
        total: total,
        total_pages: (total.to_f / per_page).ceil
      }
    end

    def validate_pagination
      page = Integer(params.fetch(:page, DEFAULT_PAGE), exception: false)
      per_page = Integer(params.fetch(:per_page, DEFAULT_PER_PAGE), exception: false)

      return if page&.positive? && per_page&.between?(1, 100)

      render json: { error: 'invalid pagination parameters' }, status: :bad_request
    end
  end
end
