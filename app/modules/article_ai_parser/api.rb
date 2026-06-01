module ArticleAiParser
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

    rescue_from ArgumentError do |e|
      error!({ error: e.message }, 400)
    end

    rescue_from ActiveRecord::RecordNotFound do |e|
      error!({ error: e.message }, 404)
    end

    rescue_from ActiveRecord::RecordNotUnique do |e|
      error!({ error: e.message }, 409)
    end

    rescue_from RuntimeError do |e|
      error!({ error: e.message }, 502)
    end

    rescue_from Faraday::Error do |e|
      body = e.respond_to?(:response) && e.response ? e.response[:body] : nil
      details = body.is_a?(Hash) ? body.dig("error", "message") || body.to_s : body
      error!({ error: "AI service error: #{e.message}", details: details }, 502)
    end

    desc "Parse raw text content via AI and create a draft article"
    params do
      requires :original_content, type: String, desc: "Raw travel notes text"
    end
    post "article_ai_parser" do
      article = ArticleAiParser::Services::ParseArticleService.call(
        params[:original_content],
        user: current_user
      )
      present article, with: ArticleManagement::Serializers::ArticleSerializer
    end
  end
end
