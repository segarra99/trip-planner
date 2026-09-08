# frozen_string_literal: true

module Api
  class CategoriesController < BaseController
    def index
      total = Category.count
      page, per_page = pagination_params

      categories = Category
                   .order(:id)
                   .limit(per_page)
                   .offset((page - 1) * per_page)

      render json: {
        categories: categories,
        pagination: pagination_metadata(page, per_page, total)
      }
    end
  end
end
