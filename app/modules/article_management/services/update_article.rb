module ArticleManagement
  module Services
    class UpdateArticle
      ALLOWED_FIELDS = %i[
        title parsed_fields original_content content_hash
      ].freeze

      def self.call(article_id, params)
        article = Article.find(article_id)
        attrs = params.to_h.symbolize_keys.slice(*ALLOWED_FIELDS)
        article.update!(attrs)
        article
      end
    end
  end
end
