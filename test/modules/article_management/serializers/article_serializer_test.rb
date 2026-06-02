require "test_helper"

module ArticleManagement
  module Serializers
    class ArticleSerializerTest < ActiveSupport::TestCase
      def parsed_fields
        {
          "title" => "AI Title",
          "intro_hook" => "AI intro",
          "main_article_body" => [{ "heading" => "AI Section", "content" => "AI content" }],
          "best_for" => "everyone",
          "not_for" => "no one",
          "ethics_safety_notes" => "AI safety",
          "key_facts" => [{ "label" => "AI Fact", "value" => "AI value" }]
        }
      end

      def serialize(article)
        ArticleSerializer.new(article).serializable_hash
      end

      test "reads from parsed_fields when updated_fields is nil" do
        article = Article.new(title: "Test", parsed_fields: parsed_fields, updated_fields: nil)
        result = serialize(article)

        assert_equal "AI intro", result[:intro_hook]
        assert_equal "everyone", result[:best_for]
      end

      test "reads from updated_fields when key exists" do
        article = Article.new(
          title: "Test",
          parsed_fields: parsed_fields,
          updated_fields: { "intro_hook" => "User edited intro" }
        )
        result = serialize(article)

        assert_equal "User edited intro", result[:intro_hook]
        assert_equal "everyone", result[:best_for]
      end

      test "reads nil from updated_fields when key exists with nil value" do
        article = Article.new(
          title: "Test",
          parsed_fields: parsed_fields,
          updated_fields: { "intro_hook" => nil }
        )
        result = serialize(article)

        assert_nil result[:intro_hook]
      end

      test "falls back to parsed_fields when key missing from updated_fields" do
        article = Article.new(
          title: "Test",
          parsed_fields: parsed_fields,
          updated_fields: { "best_for" => "edited" }
        )
        result = serialize(article)

        assert_equal "AI intro", result[:intro_hook]
        assert_equal "edited", result[:best_for]
      end

      test "title is exposed directly from column" do
        article = Article.new(title: "Direct Title", parsed_fields: parsed_fields)
        result = serialize(article)

        assert_equal "Direct Title", result[:title]
      end

      test "main_article_body falls back to empty array when nil in both sources" do
        article = Article.new(
          title: "Test",
          parsed_fields: { "title" => "AI Title" }
        )
        result = serialize(article)

        assert_equal [], result[:main_article_body]
      end

      test "key_facts falls back to empty array when nil in both sources" do
        article = Article.new(
          title: "Test",
          parsed_fields: { "title" => "AI Title" }
        )
        result = serialize(article)

        assert_equal [], result[:key_facts]
      end

      test "main_article_body falls back to empty array when nil in updated_fields" do
        article = Article.new(
          title: "Test",
          parsed_fields: { "title" => "AI Title", "main_article_body" => [{ "heading" => "Original", "content" => "Content" }] },
          updated_fields: { "main_article_body" => nil }
        )
        result = serialize(article)

        assert_equal [], result[:main_article_body]
      end
    end
  end
end
