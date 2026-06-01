module ArticleManagement
  module Serializers
    class ArticleSerializer < Grape::Entity
      expose :title
      expose :intro_hook do |article|
        article.parsed_fields&.dig("intro_hook")
      end
      expose :main_article_body do |article|
        article.parsed_fields&.dig("main_article_body") || []
      end
      expose :best_for do |article|
        article.parsed_fields&.dig("best_for")
      end
      expose :not_for do |article|
        article.parsed_fields&.dig("not_for")
      end
      expose :ethics_safety_notes do |article|
        article.parsed_fields&.dig("ethics_safety_notes")
      end
      expose :key_facts do |article|
        article.parsed_fields&.dig("key_facts") || []
      end
    end
  end
end
