module ArticleManagement
  module Queries
    class ArticleSearch
      def self.call(params = {})
        scope = Article.all

        if params[:status].present?
          scope = scope.where(status: params[:status])
        end

        scope.order(created_at: :desc)
      end
    end
  end
end
