module ArticleManagement
  class API < BaseAPI
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
      articles = ArticleManagement::Queries::ArticleSearch.call(params, user: current_user)
      present articles, with: ArticleManagement::Serializers::ArticleSerializer
    end

    desc "Get a single article"
    params do
      requires :id, type: Integer, desc: "Article ID"
    end
    get "article_management/:id" do
      article = current_user.articles.find(params[:id])
      present article, with: ArticleManagement::Serializers::ArticleSerializer
    end

    desc "Update an article"
    params do
      requires :id, type: Integer, desc: "Article ID"
      optional :title, type: String
      optional :intro_hook, type: String
      optional :main_article_body, type: Array do
        requires :heading, type: String
        requires :content, type: String
      end
      optional :best_for, type: String
      optional :not_for, type: String
      optional :ethics_safety_notes, type: String
      optional :key_facts, type: Array do
        requires :label, type: String
        requires :value, type: String
      end
    end
    put "article_management/:id" do
      article = current_user.articles.find(params[:id])
      article = ArticleManagement::Services::UpdateArticle.call(
        article.id,
        declared(params, include_missing: false)
      )
      present article, with: ArticleManagement::Serializers::ArticleSerializer
    end

    desc "Delete an article"
    params do
      requires :id, type: Integer, desc: "Article ID"
    end
    delete "article_management/:id" do
      article = current_user.articles.find(params[:id])
      article.destroy!
      status 204
    end

    desc "Change article status"
    params do
      requires :id, type: Integer, desc: "Article ID"
      requires :status, type: String, values: %w[draft reviewed published]
    end
    patch "article_management/:id/status" do
      article = current_user.articles.find(params[:id])
      article = ArticleManagement::Services::ChangeArticleStatus.call(
        article.id,
        params[:status]
      )
      present article, with: ArticleManagement::Serializers::ArticleSerializer
    end
  end
end
