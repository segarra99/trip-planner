# frozen_string_literal: true

class ApplicationController < ActionController::API
  DEFAULT_PAGE = 1
  DEFAULT_PER_PAGE = 10

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  private

  def render_not_found(exception)
    render json: { error: "#{exception.model} not found" }, status: :not_found
  end
end
