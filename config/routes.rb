Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  mount Auth::API => "/api/v1"
  mount ArticleManagement::API => "/api/v1"
  mount ArticleAiParser::API => "/api/v1"
end
