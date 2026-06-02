require "test_helper"

class FakeOpenAIClient
  def initialize(response = nil)
    @response = response
    @chat_called = false
  end

  def chat(parameters:)
    @chat_called = true
    @response
  end

  def verify_chat_called
    raise "Expected chat to have been called" unless @chat_called
  end

  def verify_chat_not_called
    raise "Chat should not have been called" if @chat_called
  end
end

module ArticleAiParser
  module Services
    class ParseArticleServiceTest < ActiveSupport::TestCase
      def fake_openai_client(parsed_response)
        FakeOpenAIClient.new(parsed_response)
      end

      def valid_parsed_response
        {
          "choices" => [
            { "message" => { "content" => JSON.generate(valid_parsed_data) } }
          ]
        }
      end

      def valid_parsed_data
        {
          "title" => "Test Title",
          "intro_hook" => "Test hook.",
          "main_article_body" => [
            { "heading" => "Section 1", "content" => "Content here." }
          ],
          "best_for" => "everyone",
          "not_for" => "no one",
          "ethics_safety_notes" => "Be safe.",
          "key_facts" => [
            { "label" => "Fact 1", "value" => "Value 1" },
            { "label" => "Fact 2", "value" => "Value 2" }
          ]
        }
      end

      test "creates new article and calls OpenAI when no duplicate exists" do
        client = fake_openai_client(valid_parsed_response)

        article = ParseArticleService.call(
          "Some unique travel notes here.",
          user: users(:nhan),
          openai_client: client
        )

        assert article.persisted?
        assert_equal "Test Title", article.title
        assert_equal "Test hook.", article.parsed_fields["intro_hook"]
        assert_nil article.updated_fields
        client.verify_chat_called
      end

      test "skips OpenAI and reuses parsed_fields when duplicate content_hash exists" do
        existing = Article.create!(
          title: "Original",
          original_content: "Duplicate content",
          parsed_fields: valid_parsed_data,
          fields_version: 1,
          content_hash: Digest::MD5.hexdigest("Duplicate content"),
          user: users(:nhan),
          status: :draft
        )

        client = FakeOpenAIClient.new

        article = ParseArticleService.call(
          "Duplicate content",
          user: users(:nhan),
          openai_client: client
        )

        assert article.persisted?
        refute_equal existing.id, article.id, "should be a new article record"
        assert_equal existing.parsed_fields, article.parsed_fields
        assert_nil article.updated_fields
        client.verify_chat_not_called
      end

      test "raises error for blank content" do
        assert_raises(ArgumentError) do
          ParseArticleService.call("", user: users(:nhan))
        end
      end

      test "raises error for too-short content" do
        assert_raises(ArgumentError) do
          ParseArticleService.call("abc", user: users(:nhan))
        end
      end
    end
  end
end
