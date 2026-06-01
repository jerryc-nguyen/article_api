require "test_helper"

module ArticleManagement
  class ApiTest < ActiveSupport::TestCase
    include Rack::Test::Methods

    def app
      Rails.application
    end

    setup do
      Article.delete_all
      @article = Article.create!(
        title: "Test Article",
        status: "draft"
      )
    end

    test "GET /api/v1/article_management returns articles" do
      get "/api/v1/article_management"

      assert last_response.ok?
      body = JSON.parse(last_response.body)
      assert_kind_of Array, body
      assert_equal 1, body.length
    end

    test "GET /api/v1/article_management filters by status" do
      Article.create!(title: "Reviewed One", status: "reviewed")

      get "/api/v1/article_management", status: "draft"

      assert last_response.ok?
      body = JSON.parse(last_response.body)
      assert_equal 1, body.length
      assert_equal "draft", body.first["status"]
    end

    test "GET /api/v1/article_management/:id returns article" do
      get "/api/v1/article_management/#{@article.id}"

      assert last_response.ok?
      body = JSON.parse(last_response.body)
      assert_equal @article.id, body["id"]
      assert_equal "Test Article", body["title"]
    end

    test "GET /api/v1/article_management/:id returns 404 for missing" do
      get "/api/v1/article_management/99999"

      assert last_response.not_found?
    end

    test "PUT /api/v1/article_management/:id updates article" do
      put "/api/v1/article_management/#{@article.id}",
        { title: "Updated Title", original_content: "New content" }.to_json,
        "CONTENT_TYPE" => "application/json"

      assert last_response.ok?
      body = JSON.parse(last_response.body)
      assert_equal "Updated Title", body["title"]
      assert_equal "New content", body["original_content"]

      @article.reload
      assert_equal "Updated Title", @article.title
    end

    test "PATCH /api/v1/article_management/:id/status changes status" do
      patch "/api/v1/article_management/#{@article.id}/status",
        { status: "reviewed" }.to_json,
        "CONTENT_TYPE" => "application/json"

      assert last_response.ok?
      body = JSON.parse(last_response.body)
      assert_equal "reviewed", body["status"]

      @article.reload
      assert_equal "reviewed", @article.status
    end

    test "PATCH /api/v1/article_management/:id/status rejects invalid transition" do
      patch "/api/v1/article_management/#{@article.id}/status",
        { status: "published" }.to_json,
        "CONTENT_TYPE" => "application/json"

      assert_equal 400, last_response.status
      body = JSON.parse(last_response.body)
      assert_includes body["error"], "Cannot transition"
    end
  end
end
