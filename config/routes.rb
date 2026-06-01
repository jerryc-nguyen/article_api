require_relative "../app/api/articles"
require_relative "../app/api/base_api"

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  mount API::BaseAPI => "/"
end
