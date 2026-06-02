require "test_helper"

module ArticleManagement
  module Queries
    class ArticleSearchTest < ActiveSupport::TestCase
      test "returns all articles ordered by created_at desc" do
        Article.delete_all
        user = users(:nhan)
        older = Article.create!(title: "Older", created_at: 2.days.ago, user: user)
        newer = Article.create!(title: "Newer", created_at: 1.day.ago, user: user)

        result = ArticleSearch.call

        assert_equal [newer, older], result.to_a
      end

      test "filters by status" do
        result = ArticleSearch.call({status: "draft"})

        assert_equal 1, result.count
        assert_equal articles(:draft_article).id, result.first.id
      end

      test "returns empty when no match" do
        result = ArticleSearch.call({status: "nonexistent"})

        assert result.empty?
      end

      test "returns all when no filter provided" do
        result = ArticleSearch.call

        assert_equal Article.count, result.count
      end

      test "scopes to user when user parameter provided" do
        user = users(:nhan)
        result = ArticleSearch.call(user: user)

        assert_equal user.articles.count, result.count
        result.each do |article|
          assert_equal user.id, article.user_id
        end
      end
    end
  end
end
