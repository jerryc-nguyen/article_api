# Article AI Parser Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement ArticleAiParser module — accept raw text, call OpenAI to extract structured travel article fields, create draft Article.

**Architecture:** Synchronous POST endpoint → ParseArticleService validates input → OpenAI chat completion (gpt-4o-mini, JSON mode) → store result as new Article.

**Tech Stack:** Rails 8.1, Grape API, ruby-openai, gpt-4o-mini, SQLite

---

## File Structure

**New files:**
- `app/modules/article_ai_parser/services/parse_article_service.rb`
- `app/modules/article_ai_parser/api.rb`
- `test/modules/article_ai_parser/services/parse_article_service_test.rb`
- `test/modules/article_ai_parser/api_test.rb`

**Modified files:**
- `Gemfile` — add `ruby-openai`
- `config/routes.rb` — mount API

**Reused (no changes):**
- `ArticleManagement::Serializers::ArticleSerializer`
- `app/models/article.rb`
- `config/initializers/modules.rb` (auto-loads new module)

---

### Task 1: Add ruby-openai gem

**Files:**
- Modify: `Gemfile`

- [ ] **Step 1: Add gem to Gemfile**

```ruby
# Insert after grape-entity line (line 40)
gem "ruby-openai"
```

- [ ] **Step 2: Install**

Run: `bundle install`
Expected: `Bundle complete!`

- [ ] **Step 3: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "chore: add ruby-openai gem"
```

---

### Task 2: Create ParseArticleService

**Files:**
- Create: `app/modules/article_ai_parser/services/parse_article_service.rb`
- Create: `test/modules/article_ai_parser/services/parse_article_service_test.rb`

- [ ] **Step 1: Create test file**

```ruby
# test/modules/article_ai_parser/services/parse_article_service_test.rb
require "test_helper"

module ArticleAiParser
  module Services
    class ParseArticleServiceTest < ActiveSupport::TestCase
      test "creates article from valid content" do
        content = "Komodo boat trips start from Labuan Bajo. Most trips are 3D2N."
        parsed = {
          "title" => "Komodo Boat Trip Guide",
          "intro_hook" => "An unforgettable adventure.",
          "main_article_body" => [{ "heading" => "Overview", "content" => "Details." }],
          "best_for" => "Adventure travellers",
          "not_for" => "Luxury seekers",
          "ethics_safety_notes" => "Avoid feeding wildlife.",
          "key_facts" => [
            { "label" => "Duration", "value" => "3D2N" },
            { "label" => "Price", "value" => "$250-$600" }
          ]
        }
        client = stub_openai(parsed.to_json)

        article = ParseArticleService.call(content, openai_client: client)

        assert_predicate article, :persisted?
        assert_equal "Komodo Boat Trip Guide", article.title
        assert_equal "draft", article.status
        assert_equal 1, article.fields_version
        assert_equal Digest::MD5.hexdigest(content), article.content_hash
        assert_equal content, article.original_content
        assert_equal parsed, article.parsed_fields
      end

      test "raises for blank content" do
        assert_raises(ArgumentError, match: /required/) do
          ParseArticleService.call("")
        end
      end

      test "raises for short content" do
        assert_raises(ArgumentError, match: /too short/) do
          ParseArticleService.call("Hi")
        end
      end

      test "raises for content exceeding max length" do
        long = "a" * 100_001
        assert_raises(ArgumentError, match: /exceeds maximum/) do
          ParseArticleService.call(long)
        end
      end

      test "raises for duplicate content" do
        content = "Some unique travel content here."
        hash = Digest::MD5.hexdigest(content)
        Article.create!(title: "Existing", content_hash: hash, status: :draft)

        assert_raises(ActiveRecord::RecordNotUnique, match: /already exists/) do
          ParseArticleService.call(content, openai_client: stub_openai("{}"))
        end
      end

      test "raises when OpenAI returns empty" do
        client = stub_openai("")

        assert_raises(RuntimeError, match: /empty response/) do
          ParseArticleService.call("Valid content here.", openai_client: client)
        end
      end

      test "raises when OpenAI returns invalid JSON" do
        client = stub_openai("not json")

        assert_raises(RuntimeError, match: /malformed/) do
          ParseArticleService.call("Valid content here.", openai_client: client)
        end
      end

      test "falls back to truncated content for blank AI title" do
        content = "A" * 60
        parsed = { "title" => "", "intro_hook" => "Test",
          "main_article_body" => [{ "heading" => "H", "content" => "C" }],
          "best_for" => "All", "not_for" => "None",
          "ethics_safety_notes" => "N/A",
          "key_facts" => [{ "label" => "A", "value" => "B" }, { "label" => "C", "value" => "D" }] }
        client = stub_openai(parsed.to_json)

        article = ParseArticleService.call(content, openai_client: client)

        assert_equal content.truncate(50), article.title
      end

      private

      def stub_openai(content)
        client = Minitest::Mock.new
        client.expect(:chat, { "choices" => [{ "message" => { "content" => content } }] }, [Hash])
        client
      end
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/modules/article_ai_parser/services/parse_article_service_test.rb`
Expected: `LoadError: cannot load such file`

- [ ] **Step 3: Create service implementation**

```ruby
# app/modules/article_ai_parser/services/parse_article_service.rb
require "digest"

module ArticleAiParser
  module Services
    class ParseArticleService
      MAX_CONTENT_LENGTH = 100_000
      MIN_CONTENT_LENGTH = 10

      def self.call(original_content, openai_client: nil)
        new(original_content, openai_client: openai_client).call
      end

      def initialize(original_content, openai_client: nil)
        @original_content = original_content
        @openai_client = openai_client || OpenAI::Client.new
      end

      def call
        validate!
        check_duplicate!

        response = @openai_client.chat(
          parameters: {
            model: "gpt-4o-mini",
            messages: [
              { role: "system", content: system_prompt },
              { role: "user", content: @original_content }
            ],
            response_format: { type: "json_object" },
            temperature: 0
          }
        )

        parsed = parse_response(response)

        Article.create!(
          title: extract_title(parsed),
          original_content: @original_content,
          parsed_fields: parsed,
          fields_version: 1,
          content_hash: Digest::MD5.hexdigest(@original_content),
          status: :draft
        )
      end

      private

      def validate!
        raise ArgumentError, "original_content is required" if @original_content.blank?
        raise ArgumentError, "content too short to parse" if @original_content.strip.length < MIN_CONTENT_LENGTH
        raise ArgumentError, "content exceeds maximum length" if @original_content.length > MAX_CONTENT_LENGTH
        raise ArgumentError, "invalid content encoding" unless @original_content.dup.force_encoding("UTF-8").valid_encoding?
      end

      def check_duplicate!
        hash = Digest::MD5.hexdigest(@original_content)
        if Article.exists?(content_hash: hash)
          raise ActiveRecord::RecordNotUnique, "article with this content already exists"
        end
      end

      def parse_response(response)
        content = response.dig("choices", 0, "message", "content")
        raise "AI returned empty response" if content.blank?

        JSON.parse(content)
      rescue JSON::ParserError
        raise "AI returned malformed response"
      end

      def extract_title(parsed)
        title = parsed["title"]
        return @original_content.truncate(50) if title.blank?
        title.truncate(255)
      end

      def system_prompt
        <<~PROMPT
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
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/modules/article_ai_parser/services/parse_article_service_test.rb`
Expected: 8 tests, 0 failures, 0 errors

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add ParseArticleService with OpenAI integration"
```

---

### Task 3: Create API endpoint and mount routes

**Files:**
- Create: `app/modules/article_ai_parser/api.rb`
- Create: `test/modules/article_ai_parser/api_test.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Create API test file**

```ruby
# test/modules/article_ai_parser/api_test.rb
require "test_helper"

module ArticleAiParser
  class ApiTest < ActiveSupport::TestCase
    include Rack::Test::Methods

    def app
      Rails.application
    end

    test "POST returns 201 with article" do
      Services::ParseArticleService.stub(:call, ->(content, **_) {
        Article.create!(
          title: "Test Title",
          original_content: content,
          parsed_fields: { "title" => "Test Title" },
          fields_version: 1,
          content_hash: Digest::MD5.hexdigest(content),
          status: :draft
        )
      }) do
        post "/api/v1/article_ai_parser",
          { original_content: "Valid travel notes here." }.to_json,
          "CONTENT_TYPE" => "application/json"

        assert_equal 201, last_response.status
        body = JSON.parse(last_response.body)
        assert_equal "Test Title", body["title"]
        assert_equal "draft", body["status"]
      end
    end

    test "POST returns 400 for blank content" do
      post "/api/v1/article_ai_parser",
        { original_content: "" }.to_json,
        "CONTENT_TYPE" => "application/json"

      assert_equal 400, last_response.status
      body = JSON.parse(last_response.body)
      assert_includes body["error"], "required"
    end

    test "POST returns 502 when AI service fails" do
      Services::ParseArticleService.stub(:call, ->(*) { raise "AI service unavailable" }) do
        post "/api/v1/article_ai_parser",
          { original_content: "Valid notes." }.to_json,
          "CONTENT_TYPE" => "application/json"

        assert_equal 502, last_response.status
      end
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/modules/article_ai_parser/api_test.rb`
Expected: LoadError or routing error — API file and routes not set up yet

- [ ] **Step 3: Create API implementation**

```ruby
# app/modules/article_ai_parser/api.rb
module ArticleAiParser
  class Api < Grape::API
    format :json

    rescue_from ArgumentError do |e|
      error!({ error: e.message }, 400)
    end

    rescue_from ActiveRecord::RecordNotFound do |e|
      error!({ error: e.message }, 404)
    end

    rescue_from RuntimeError do |e|
      error!({ error: e.message }, 502)
    end

    desc "Parse raw text content via AI and create a draft article"
    params do
      requires :original_content, type: String, desc: "Raw travel notes text"
    end
    post "article_ai_parser" do
      article = ArticleAiParser::Services::ParseArticleService.call(
        params[:original_content]
      )
      present article, with: ArticleManagement::Serializers::ArticleSerializer
    end
  end
end
```

- [ ] **Step 4: Update routes**

```ruby
# config/routes.rb
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  mount ArticleManagement::Api => "/api/v1"
  mount ArticleAiParser::Api => "/api/v1"
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/modules/article_ai_parser/api_test.rb`
Expected: 3 tests, 0 failures, 0 errors

- [ ] **Step 6: Run full suite to check no regressions**

Run: `bin/rails test`
Expected: 24 tests, 0 failures (21 existing + 8 service + 3 API)

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: add ArticleAiParser API endpoint"
```

---

## Self-Review

1. **Spec coverage:** Each spec requirement has a task:
   - Input validation → Task 2 (service), Task 3 (API error mapping)
   - OpenAI call → Task 2 service logic
   - Duplicate hash check → Task 2 `check_duplicate!`
   - Error handling for blank/short/long → Task 2 validate!, Task 3 API rescue
   - OpenAI empty/invalid JSON → Task 2 `parse_response`
   - Title fallback → Task 2 `extract_title`
   - 201/400/502 responses → Task 3 API + tests
2. **Placeholders:** None — every step has complete code.
3. **Type consistency:** All method signatures match between test and implementation.
