require "test_helper"

module ArticleManagement
  module Services
    class UpdateArticleTest < ActiveSupport::TestCase
      setup do
        @article = articles(:draft_article)
      end

      test "writes parsed field edits to updated_fields, not parsed_fields" do
        UpdateArticle.call(@article.id, { intro_hook: "Edited hook" })

        @article.reload
        assert_equal "Edited hook", @article.updated_fields["intro_hook"]
        assert_nil @article.parsed_fields
      end

      test "sets field to nil in updated_fields when explicit nil passed" do
        UpdateArticle.call(@article.id, { intro_hook: nil })

        @article.reload
        assert @article.updated_fields.key?("intro_hook")
        assert_nil @article.updated_fields["intro_hook"]
      end

      test "updates title via direct column" do
        UpdateArticle.call(@article.id, { title: "Updated Title" })

        @article.reload
        assert_equal "Updated Title", @article.title
      end

      test "does not modify parsed_fields when updating title only" do
        UpdateArticle.call(@article.id, { title: "New Title" })

        @article.reload
        assert_nil @article.parsed_fields
      end

      test "raises error for non-existent article" do
        assert_raises(ActiveRecord::RecordNotFound) do
          UpdateArticle.call(99999, { title: "Nope" })
        end
      end

      test "only updates provided fields" do
        original_title = @article.title

        UpdateArticle.call(@article.id, { intro_hook: "Only this changes" })

        @article.reload
        assert_equal original_title, @article.title
        assert_equal "Only this changes", @article.updated_fields["intro_hook"]
      end

      test "merges multiple edits into updated_fields" do
        UpdateArticle.call(@article.id, { intro_hook: "First edit" })
        UpdateArticle.call(@article.id, { best_for: "Second edit" })

        @article.reload
        assert_equal "First edit", @article.updated_fields["intro_hook"]
        assert_equal "Second edit", @article.updated_fields["best_for"]
      end

      test "overwrites existing updated_fields key" do
        UpdateArticle.call(@article.id, { intro_hook: "First" })
        UpdateArticle.call(@article.id, { intro_hook: "Second" })

        @article.reload
        assert_equal "Second", @article.updated_fields["intro_hook"]
      end
    end
  end
end
