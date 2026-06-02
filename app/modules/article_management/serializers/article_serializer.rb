module ArticleManagement
  module Serializers
    class ArticleSerializer < Grape::Entity
      expose :title

      PARSED_FIELD_NAMES = %i[intro_hook main_article_body best_for not_for ethics_safety_notes key_facts].freeze
      ARRAY_FIELDS = %i[main_article_body key_facts].freeze

      PARSED_FIELD_NAMES.each do |field|
        expose field do |article|
          value = if article.updated_fields&.key?(field.to_s)
                    article.updated_fields[field.to_s]
                  else
                    article.parsed_fields&.dig(field.to_s)
                  end
          ARRAY_FIELDS.include?(field) ? value || [] : value
        end
      end
    end
  end
end
