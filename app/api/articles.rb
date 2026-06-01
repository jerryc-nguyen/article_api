module API
  class Articles < Grape::API
    desc "Get all articles"
    get :articles do
      Article.all
    end

    desc "Get a single article"
    params do
      requires :id, type: Integer, desc: "Article ID"
    end
    get "articles/:id" do
      Article.find(params[:id])
    end

    desc "Create an article"
    params do
      requires :title, type: String, desc: "Article title"
      requires :body, type: String, desc: "Article body"
    end
    post :articles do
      Article.create!(title: params[:title], body: params[:body])
    end

    desc "Update an article"
    params do
      requires :id, type: Integer, desc: "Article ID"
      optional :title, type: String, desc: "Article title"
      optional :body, type: String, desc: "Article body"
    end
    put "articles/:id" do
      article = Article.find(params[:id])
      article.update!(declared(params, include_missing: false))
      article
    end

    desc "Delete an article"
    params do
      requires :id, type: Integer, desc: "Article ID"
    end
    delete "articles/:id" do
      Article.find(params[:id]).destroy!
      status :no_content
    end
  end
end
