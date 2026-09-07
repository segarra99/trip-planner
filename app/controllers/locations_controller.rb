# frozen_string_literal: true

class LocationsController < ApplicationController
  def index
    locations = Location.all
    locations = locations.name_matches(params[:name]) if params[:name].present?

    total = locations.count
    page = params.fetch(:page, DEFAULT_PAGE).to_i
    per_page = params.fetch(:per_page, DEFAULT_PER_PAGE).to_i

    locations = locations
                .order(:id)
                .limit(per_page)
                .offset((page - 1) * per_page)

    render json: {
      locations: locations.as_json(
        except: :location_point,
        methods: %i[latitude longitude]
      ),
      pagination: {
        page: page,
        per_page: per_page,
        total: total,
        total_pages: (total.to_f / per_page).ceil
      }
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
