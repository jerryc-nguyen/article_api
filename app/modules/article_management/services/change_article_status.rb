module ArticleManagement
  module Services
    class ChangeArticleStatus
      VALID_TRANSITIONS = {
        "draft" => %w[reviewed],
        "reviewed" => %w[draft published],
        "published" => %w[reviewed],
      }.freeze

      def self.call(article_id, new_status)
        article = Article.find(article_id)
        current = article.status

        unless VALID_TRANSITIONS.fetch(current, []).include?(new_status)
          raise ArgumentError, "Cannot transition from '#{current}' to '#{new_status}'"
        end

        article.update!(status: new_status)
        article
      end
    end
  end
end
