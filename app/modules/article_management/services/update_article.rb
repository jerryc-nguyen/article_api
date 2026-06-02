module ArticleManagement
  module Services
    class UpdateArticle
      PARSED_FIELDS = %i[
        intro_hook main_article_body best_for not_for
        ethics_safety_notes key_facts
      ].freeze

      DIRECT_FIELDS = %i[title status].freeze

      def self.call(article_id, params)
        article = Article.find(article_id)
        attrs = params.to_h.symbolize_keys

        updates = (article.updated_fields || {}).deep_symbolize_keys
        PARSED_FIELDS.each do |key|
          updates[key] = attrs.delete(key) if attrs.key?(key)
        end

        update_attrs = attrs.slice(*DIRECT_FIELDS)
        update_attrs[:updated_fields] = updates if updates.present?

        article.update!(update_attrs)
        article
      end
    end
  end
end
