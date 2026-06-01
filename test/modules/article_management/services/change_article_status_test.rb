require "test_helper"

module ArticleManagement
  module Services
    class ChangeArticleStatusTest < ActiveSupport::TestCase
      test "transitions from draft to reviewed" do
        article = articles(:draft_article)

        ChangeArticleStatus.call(article.id, "reviewed")

        article.reload
        assert_equal "reviewed", article.status
      end

      test "transitions from reviewed to published" do
        article = articles(:reviewed_article)

        ChangeArticleStatus.call(article.id, "published")

        article.reload
        assert_equal "published", article.status
      end

      test "transitions from reviewed back to draft" do
        article = articles(:reviewed_article)

        ChangeArticleStatus.call(article.id, "draft")

        article.reload
        assert_equal "draft", article.status
      end

      test "prevents invalid transition from draft to published" do
        article = articles(:draft_article)

        assert_raises(ArgumentError) do
          ChangeArticleStatus.call(article.id, "published")
        end
      end

      test "prevents invalid transition from published to draft" do
        article = articles(:published_article)

        assert_raises(ArgumentError) do
          ChangeArticleStatus.call(article.id, "draft")
        end
      end

      test "raises error for non-existent article" do
        assert_raises(ActiveRecord::RecordNotFound) do
          ChangeArticleStatus.call(99999, "reviewed")
        end
      end
    end
  end
end
