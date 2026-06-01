require "test_helper"

module ArticleManagement
  module Services
    class UpdateArticleTest < ActiveSupport::TestCase
      test "updates allowed fields" do
        article = articles(:draft_article)

        UpdateArticle.call(article.id, { title: "Updated Title", content_hash: "abc123" })

        article.reload
        assert_equal "Updated Title", article.title
        assert_equal "abc123", article.content_hash
      end

      test "does not update status through update" do
        article = articles(:draft_article)

        UpdateArticle.call(article.id, { status: "published" })

        article.reload
        assert_equal "draft", article.status
      end

      test "raises error for non-existent article" do
        assert_raises(ActiveRecord::RecordNotFound) do
          UpdateArticle.call(99999, { title: "Nope" })
        end
      end

      test "only updates provided fields" do
        article = articles(:draft_article)
        original_title = article.title

        UpdateArticle.call(article.id, { original_content: "Only this changes" })

        article.reload
        assert_equal original_title, article.title
        assert_equal "Only this changes", article.original_content
      end
    end
  end
end
