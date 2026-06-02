module ArticleAiParser
  module Services
    class ParseArticleService
      MODEL = "gpt-4o-mini".freeze
      MIN_CONTENT_LENGTH = 10
      MAX_CONTENT_LENGTH = 100_000
      TITLE_FALLBACK_LENGTH = 50
      TITLE_MAX_LENGTH = 255
      FIELDS_VERSION = 1

      SYSTEM_PROMPT = <<~PROMPT.freeze
        You are a travel article editor. Given raw travel notes, extract structured information as JSON.

        Schema:
        {
          "title": "string (compelling article title under 255 chars)",
          "intro_hook": "string (1-2 sentence hook)",
          "main_article_body": [
            { "heading": "string", "content": "string" }
          ],
          "best_for": "string (comma-separated)",
          "not_for": "string (comma-separated)",
          "ethics_safety_notes": "string",
          "key_facts": [
            { "label": "string", "value": "string" }
          ]
        }

        Rules:
        - title must be under 255 characters
        - main_article_body must have at least 1 section
        - key_facts must have at least 2 items
        - Return ONLY valid JSON, no markdown, no explanation
      PROMPT

      def self.call(original_content, user:, openai_client: OpenAI::Client.new)
        new(original_content, user: user, openai_client: openai_client).call
      end

      def initialize(original_content, user:, openai_client:)
        @original_content = original_content
        @user = user
        @openai_client = openai_client
      end

      def call
        validate_content!

        existing = find_existing
        if existing
          create_article!(existing.parsed_fields)
        else
          response = @openai_client.chat(parameters: chat_parameters)
          parsed = parse_response(response)
          create_article!(parsed)
        end
      end

      private

      def validate_content!
        raise ArgumentError, "original_content is required" if @original_content.blank?
        raise ArgumentError, "content too short to parse" if @original_content.length < MIN_CONTENT_LENGTH
        raise ArgumentError, "content exceeds maximum length" if @original_content.length > MAX_CONTENT_LENGTH
        raise ArgumentError, "invalid content encoding" unless @original_content.dup.force_encoding("UTF-8").valid_encoding?
      end

      def content_hash
        @content_hash ||= Digest::MD5.hexdigest(@original_content)
      end

      def find_existing
        Article.find_by(content_hash: content_hash)
      end

      def chat_parameters
        {
          model: MODEL,
          response_format: { type: "json_object" },
          temperature: 0,
          messages: [
            { role: "system", content: SYSTEM_PROMPT },
            { role: "user", content: @original_content }
          ]
        }
      end

      def parse_response(response)
        content = response.dig("choices", 0, "message", "content")
        raise RuntimeError, "AI returned empty response" if content.blank?
        JSON.parse(content)
      rescue JSON::ParserError
        raise RuntimeError, "AI returned malformed response"
      end

      def extract_title(parsed)
        title = parsed["title"]
        title = @original_content.truncate(TITLE_FALLBACK_LENGTH) if title.blank?
        title.truncate(TITLE_MAX_LENGTH)
      end

      def create_article!(parsed)
        Article.create!(
          title: extract_title(parsed),
          original_content: @original_content,
          parsed_fields: parsed,
          fields_version: FIELDS_VERSION,
          content_hash: content_hash,
          user: @user,
          status: :draft
        )
      end
    end
  end
end
