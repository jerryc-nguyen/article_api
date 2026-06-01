module ArticleManagement
  class Api < Grape::API
    format :json

    helpers do
      def current_user
        @current_user
      end

      def authenticate!
        header = headers["Authorization"]
        token = header&.sub(/\ABearer\s+/, "")
        @current_user = User.find_by(access_token: token)
        error!({ error: "Unauthorized" }, 401) unless @current_user
      end
    end

    before do
      authenticate!
    end

    rescue_from ActiveRecord::RecordNotFound do |e|
      error!({ error: e.message }, 404)
    end

    rescue_from ArgumentError do |e|
      error!({ error: e.message }, 400)
    end

    desc "List all articles"
    get "article_management" do
      articles = ArticleManagement::Queries::ArticleSearch.call(params)
      present articles, with: ArticleManagement::Serializers::ArticleSerializer
    end

    desc "Get a single article"
    params do
      requires :id, type: Integer, desc: "Article ID"
    end
    get "article_management/:id" do
      article = Article.find(params[:id])
      present article, with: ArticleManagement::Serializers::ArticleSerializer
    end

    desc "Update an article"
    params do
      requires :id, type: Integer, desc: "Article ID"
      optional :title, type: String
      optional :parsed_fields, type: String
      optional :original_content, type: String
      optional :content_hash, type: String
    end
    put "article_management/:id" do
      article = ArticleManagement::Services::UpdateArticle.call(
        params[:id],
        declared(params, include_missing: false)
      )
      present article, with: ArticleManagement::Serializers::ArticleSerializer
    end

    desc "Change article status"
    params do
      requires :id, type: Integer, desc: "Article ID"
      requires :status, type: String, values: %w[draft reviewed published]
    end
    patch "article_management/:id/status" do
      article = ArticleManagement::Services::ChangeArticleStatus.call(
        params[:id],
        params[:status]
      )
      present article, with: ArticleManagement::Serializers::ArticleSerializer
    end
  end
end
