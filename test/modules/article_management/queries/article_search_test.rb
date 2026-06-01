require "test_helper"

module ArticleManagement
  module Queries
    class ArticleSearchTest < ActiveSupport::TestCase
      test "returns all articles ordered by created_at desc" do
        Article.delete_all
        older = Article.create!(title: "Older", created_at: 2.days.ago)
        newer = Article.create!(title: "Newer", created_at: 1.day.ago)

        result = ArticleSearch.call

        assert_equal [newer, older], result.to_a
      end

      test "filters by status" do
        result = ArticleSearch.call(status: "draft")

        assert_equal 1, result.count
        assert_equal articles(:draft_article).id, result.first.id
      end

      test "returns empty when no match" do
        result = ArticleSearch.call(status: "nonexistent")

        assert result.empty?
      end

      test "returns all when no filter provided" do
        result = ArticleSearch.call

        assert_equal Article.count, result.count
      end
    end
  end
end
