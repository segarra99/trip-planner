# frozen_string_literal: true

Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

  # UI
  root 'roadtrip#index'
  get '/architecture', to: 'roadtrip#architecture'
  get '/deployment', to: 'roadtrip#deployment'

  # API
  scope module: :api do
    resources :locations, only: %i[index show]
    resources :categories, only: :index

    resources :pois, only: %i[index show] do
      collection do
        get :nearest
      end
    end

    get '/trip-planning', to: 'trip_planning#index'
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check
end
