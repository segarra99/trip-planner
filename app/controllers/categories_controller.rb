# frozen_string_literal: true

class CategoriesController < ApplicationController
  def index
    total = Category.count
    page = params.fetch(:page, DEFAULT_PAGE).to_i
    per_page = params.fetch(:per_page, DEFAULT_PER_PAGE).to_i

    categories = Category
                 .order(:id)
                 .limit(per_page)
                 .offset((page - 1) * per_page)

    render json: {
      categories: categories,
      pagination: {
        page: page,
        per_page: per_page,
        total: total,
        total_pages: (total.to_f / per_page).ceil
      }
    }
  end

end
