module ArticleManagement
  module Services
    class UpdateArticle
      PARSED_FIELDS = %i[
        intro_hook main_article_body best_for not_for
        ethics_safety_notes key_facts
      ].freeze

      DIRECT_FIELDS = %i[title].freeze

      def self.call(article_id, params)
        article = Article.find(article_id)
        attrs = params.to_h.symbolize_keys

        parsed = (article.parsed_fields || {}).deep_symbolize_keys
        PARSED_FIELDS.each do |key|
          parsed[key] = attrs.delete(key) if attrs.key?(key)
        end

        update_attrs = attrs.slice(*DIRECT_FIELDS)
        update_attrs[:parsed_fields] = parsed if parsed.present?

        article.update!(update_attrs)
        article
      end
    end
  end
end
