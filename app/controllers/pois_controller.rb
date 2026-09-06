class PoisController < ActionController::API
  def index
    pois = Poi.all
    pois = pois.name_matches(params[:name]) if params[:name].present?
    pois = pois.with_category(params[:category]) if params[:category].present?

    render json: pois.as_json(include: :categories)
  end

  def show
    poi = Poi.find(params[:id])

    render json: poi.as_json(include: :categories)
  end
end
