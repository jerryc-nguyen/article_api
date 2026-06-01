Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  mount ArticleManagement::Api => "/api/v1"
  mount ArticleAiParser::Api => "/api/v1"
end
