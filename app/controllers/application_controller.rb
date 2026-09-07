# frozen_string_literal: true

class ApplicationController < ActionController::API
  DEFAULT_PAGE = 1
  DEFAULT_PER_PAGE = 10

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  private

  def render_not_found(exception)
    render json: { error: "#{exception.model} not found" }, status: :not_found
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
end
