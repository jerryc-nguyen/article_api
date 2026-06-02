require "test_helper"

module ArticleManagement
  class ApiTest < ActiveSupport::TestCase
    include Rack::Test::Methods

    def app
      Rails.application
    end

    def auth_header(user)
      { "HTTP_AUTHORIZATION" => "Bearer #{user.access_token}" }
    end

    setup do
      Article.delete_all
      @user = users(:nhan)
      @other_user = users(:other)
      @article = Article.create!(
        title: "Test Article",
        status: "draft",
        user: @user
      )
    end

    test "GET /api/v1/article_management returns only current user articles" do
      Article.create!(title: "Other User Article", status: "draft", user: @other_user)

      get "/api/v1/article_management", {}, auth_header(@user)

      assert last_response.ok?
      body = JSON.parse(last_response.body)
      assert_equal 1, body.length
      assert_equal @article.title, body.first["title"]
    end

    test "GET /api/v1/article_management filters by status for current user" do
      Article.create!(title: "Reviewed One", status: "reviewed", user: @user)

      get "/api/v1/article_management", { status: "draft" }, auth_header(@user)

      assert last_response.ok?
      body = JSON.parse(last_response.body)
      assert_equal 1, body.length
    end

    test "GET /api/v1/article_management/:id returns article owned by current user" do
      get "/api/v1/article_management/#{@article.id}", {}, auth_header(@user)

      assert last_response.ok?
      body = JSON.parse(last_response.body)
      assert_equal @article.id, body["id"]
      assert_equal "Test Article", body["title"]
    end

    test "GET /api/v1/article_management/:id returns 404 for another user's article" do
      other_article = Article.create!(title: "Not Mine", status: "draft", user: @other_user)

      get "/api/v1/article_management/#{other_article.id}", {}, auth_header(@user)

      assert last_response.not_found?
    end

    test "GET /api/v1/article_management/:id returns 404 for missing" do
      get "/api/v1/article_management/99999", {}, auth_header(@user)

      assert last_response.not_found?
    end

    test "PUT /api/v1/article_management/:id updates article owned by current user" do
      put "/api/v1/article_management/#{@article.id}",
        { title: "Updated Title" }.to_json,
        auth_header(@user).merge("CONTENT_TYPE" => "application/json")

      assert last_response.ok?
      body = JSON.parse(last_response.body)
      assert_equal "Updated Title", body["title"]

      @article.reload
      assert_equal "Updated Title", @article.title
    end

    test "PUT /api/v1/article_management/:id returns 404 for another user's article" do
      other_article = Article.create!(title: "Not Mine", status: "draft", user: @other_user)

      put "/api/v1/article_management/#{other_article.id}",
        { title: "Hacked" }.to_json,
        auth_header(@user).merge("CONTENT_TYPE" => "application/json")

      assert last_response.not_found?
    end

    test "PUT /api/v1/article_management/:id returns 404 for non-existent article" do
      put "/api/v1/article_management/99999",
        { title: "Nope" }.to_json,
        auth_header(@user).merge("CONTENT_TYPE" => "application/json")

      assert last_response.not_found?
    end

    test "PATCH /api/v1/article_management/:id/status changes status" do
      patch "/api/v1/article_management/#{@article.id}/status",
        { status: "reviewed" }.to_json,
        auth_header(@user).merge("CONTENT_TYPE" => "application/json")

      assert last_response.ok?

      @article.reload
      assert_equal "reviewed", @article.status
    end

    test "PATCH /api/v1/article_management/:id/status returns 404 for another user's article" do
      other_article = Article.create!(title: "Not Mine", status: "draft", user: @other_user)

      patch "/api/v1/article_management/#{other_article.id}/status",
        { status: "reviewed" }.to_json,
        auth_header(@user).merge("CONTENT_TYPE" => "application/json")

      assert last_response.not_found?
    end

    test "PATCH /api/v1/article_management/:id/status rejects invalid transition" do
      patch "/api/v1/article_management/#{@article.id}/status",
        { status: "published" }.to_json,
        auth_header(@user).merge("CONTENT_TYPE" => "application/json")

      assert_equal 400, last_response.status
    end

    test "DELETE /api/v1/article_management/:id deletes own article" do
      delete "/api/v1/article_management/#{@article.id}", {}, auth_header(@user)

      assert_equal 204, last_response.status
      assert_not Article.exists?(@article.id)
    end

    test "DELETE /api/v1/article_management/:id returns 404 for another user's article" do
      other_article = Article.create!(title: "Not Mine", status: "draft", user: @other_user)

      delete "/api/v1/article_management/#{other_article.id}", {}, auth_header(@user)

      assert last_response.not_found?
      assert Article.exists?(other_article.id)
    end

    test "DELETE /api/v1/article_management/:id returns 404 for non-existent article" do
      delete "/api/v1/article_management/99999", {}, auth_header(@user)

      assert last_response.not_found?
    end

    test "returns 401 without auth token" do
      get "/api/v1/article_management"

      assert_equal 401, last_response.status
    end
  end
end
