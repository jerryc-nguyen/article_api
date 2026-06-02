# Article AI Parser Idempotency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `POST /api/v1/article_ai_parser` skip OpenAI calls on duplicate content, and separate user edits from AI output via a new `updated_fields` column.

**Architecture:** Add a serialized JSON `updated_fields` column to `articles`. `parsed_fields` becomes write-once (set during creation). `UpdateArticle` writes user edits to `updated_fields`. Serializer merges `updated_fields` over `parsed_fields`. `ParseArticleService` on duplicate content_hash copies existing `parsed_fields` and skips OpenAI.

**Tech Stack:** Ruby on Rails, Grape API, SQLite, OpenAI client

---

### Task 0: Add Users Fixture (needed by all tests)

**Files:**
- Create: `test/fixtures/users.yml`
- Modify: `test/fixtures/articles.yml`

- [ ] **Step 1: Create users fixture**

```yaml
# test/fixtures/users.yml
one:
  name: TestUser
  access_token: test-access-token-123
```

- [ ] **Step 2: Add user references to articles fixture**

```yaml
# test/fixtures/articles.yml
draft_article:
  title: "Komodo Boat Trip Guide"
  status: draft
  original_content: "Komodo boat trips usually start from Labuan Bajo."
  fields_version: 1
  user: one

reviewed_article:
  title: "Bali Travel Tips"
  status: reviewed
  original_content: "Bali is a beautiful island destination."
  fields_version: 1
  user: one

published_article:
  title: "Jakarta City Guide"
  status: published
  original_content: "Jakarta is the capital of Indonesia."
  fields_version: 1
  user: one
```

- [ ] **Step 3: Commit**

```bash
git add test/fixtures/users.yml test/fixtures/articles.yml
git commit -m "chore: add users fixture and wire articles to user"
```

---

### Task 1: Add `updated_fields` Migration

**Files:**
- Create: `db/migrate/20260602120000_add_updated_fields_to_articles.rb`
- Modify: `app/models/article.rb`

- [ ] **Step 1: Write the migration file**

```ruby
# db/migrate/20260602120000_add_updated_fields_to_articles.rb
class AddUpdatedFieldsToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :updated_fields, :text
  end
end
```

- [ ] **Step 2: Update Article model to serialize `updated_fields`**

```ruby
# app/models/article.rb
class Article < ApplicationRecord
  belongs_to :user

  enum :status, {
    draft: "draft",
    reviewed: "reviewed",
    published: "published",
  }, default: :draft

  validates :title, presence: true
  validates :status, presence: true, inclusion: { in: statuses.keys }

  serialize :parsed_fields, coder: JSON
  serialize :updated_fields, coder: JSON
end
```

- [ ] **Step 3: Run migration**

```bash
rails db:migrate
```

Expected: `updated_fields` column added to `articles` table, nullable, no default.

- [ ] **Step 4: Update schema.rb in git**

```bash
git add db/migrate/20260602120000_add_updated_fields_to_articles.rb db/schema.rb app/models/article.rb
git commit -m "feat: add updated_fields column to articles"
```

---

### Task 2: Update `ParseArticleService` for Idempotency

**Files:**
- Modify: `app/modules/article_ai_parser/services/parse_article_service.rb`

- [ ] **Step 1: Replace `check_duplicate!` with idempotent lookup logic**

Change the `call` method and remove `check_duplicate!`:

```ruby
# app/modules/article_ai_parser/services/parse_article_service.rb
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
```

Key changes:
- Replace `check_duplicate!` with `find_existing`
- `find_existing` returns `nil` or the existing `Article`
- If existing found, call `create_article!` with its `parsed_fields` (no OpenAI call)
- Remove `ActiveRecord::RecordNotUnique` rescue from the API (no longer raised)

- [ ] **Step 2: Remove `RecordNotUnique` rescue from parser API**

```ruby
# app/modules/article_ai_parser/api.rb
# Remove these lines:
#     rescue_from ActiveRecord::RecordNotUnique do |e|
#       error!({ error: e.message }, 409)
#     end
```

- [ ] **Step 3: Update api-contract.md — remove 409 response for parser endpoint**

In `docs/api-contract.md`, remove the "Response 409 (duplicate content)" section under AI Parser.

- [ ] **Step 4: Commit**

```bash
git add app/modules/article_ai_parser/services/parse_article_service.rb app/modules/article_ai_parser/api.rb docs/api-contract.md
git commit -m "feat: skip OpenAI call on duplicate content in ParseArticleService"
```

---

### Task 3: Update `UpdateArticle` to Write to `updated_fields`

**Files:**
- Modify: `app/modules/article_management/services/update_article.rb`

- [ ] **Step 1: Change write target from `parsed_fields` to `updated_fields`**

```ruby
# app/modules/article_management/services/update_article.rb
module ArticleManagement
  module Services
    class UpdateArticle
      PARSED_FIELDS = %i[
        intro_hook main_article_body best_for not_for
        ethics_safety_notes key_facts
      ].freeze

      DIRECT_FIELDS = %i[title].freeze

      def self.call(article_id, params)
        article = Article.find(article_id)
        attrs = params.to_h.symbolize_keys

        updates = (article.updated_fields || {}).deep_symbolize_keys
        PARSED_FIELDS.each do |key|
          updates[key] = attrs.delete(key) if attrs.key?(key)
        end

        update_attrs = attrs.slice(*DIRECT_FIELDS)
        update_attrs[:updated_fields] = updates if updates.present?

        article.update!(update_attrs)
        article
      end
    end
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add app/modules/article_management/services/update_article.rb
git commit -m "feat: write user edits to updated_fields instead of parsed_fields"
```

---

### Task 4: Update Serializer for Merged View

**Files:**
- Modify: `app/modules/article_management/serializers/article_serializer.rb`

- [ ] **Step 1: Add helper method and update each field exposure**

```ruby
# app/modules/article_management/serializers/article_serializer.rb
module ArticleManagement
  module Serializers
    class ArticleSerializer < Grape::Entity
      expose :title

      PARSED_FIELD_NAMES = %i[intro_hook main_article_body best_for not_for ethics_safety_notes key_facts].freeze

      PARSED_FIELD_NAMES.each do |field|
        expose field do |article|
          if article.updated_fields&.key?(field.to_s)
            article.updated_fields[field.to_s]
          else
            article.parsed_fields&.dig(field.to_s)
          end
        end
      end
    end
  end
end
```

This uses iteration to keep it DRY — each field follows the same merge pattern.

- [ ] **Step 2: Commit**

```bash
git add app/modules/article_management/serializers/article_serializer.rb
git commit -m "feat: merge updated_fields over parsed_fields in serializer"
```

---

### Task 5: Update `UpdateArticle` Tests

**Files:**
- Modify: `test/modules/article_management/services/update_article_test.rb`

- [ ] **Step 1: Write tests asserting writes go to `updated_fields`**

```ruby
# test/modules/article_management/services/update_article_test.rb
require "test_helper"

module ArticleManagement
  module Services
    class UpdateArticleTest < ActiveSupport::TestCase
      setup do
        @article = articles(:draft_article)
      end

      test "writes parsed field edits to updated_fields, not parsed_fields" do
        original_parsed = @article.parsed_fields

        UpdateArticle.call(@article.id, { intro_hook: "Edited hook" })

        @article.reload
        assert_equal "Edited hook", @article.updated_fields["intro_hook"]
        assert_equal original_parsed, @article.parsed_fields
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
        original_parsed = @article.parsed_fields

        UpdateArticle.call(@article.id, { title: "New Title" })

        @article.reload
        assert_equal original_parsed, @article.parsed_fields
      end

      test "raises error for non-existent article" do
        assert_raises(ActiveRecord::RecordNotFound) do
          UpdateArticle.call(99999, { title: "Nope" })
        end
      end

      test "only updates provided fields" do
        original_title = @article.title

        UpdateArticle.call(@article.id, { original_content: "Only this changes" })

        @article.reload
        assert_equal original_title, @article.title
        assert_equal "Only this changes", @article.original_content
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
```

- [ ] **Step 2: Run the tests to verify they pass**

```bash
rails test test/modules/article_management/services/update_article_test.rb
```

Expected: all tests PASS.

- [ ] **Step 3: Commit**

```bash
git add test/modules/article_management/services/update_article_test.rb
git commit -m "test: update UpdateArticle tests for updated_fields"
```

---

### Task 6: Test `ParseArticleService` Idempotency

**Files:**
- Create: `test/modules/article_ai_parser/services/parse_article_service_test.rb`

- [ ] **Step 1: Write tests for duplicate and non-duplicate flows**

```ruby
# test/modules/article_ai_parser/services/parse_article_service_test.rb
require "test_helper"

module ArticleAiParser
  module Services
    class ParseArticleServiceTest < ActiveSupport::TestCase
      def fake_openai_client(parsed_response)
        client = Minitest::Mock.new
        client.expect :chat, parsed_response do |params|
          params[:model] == "gpt-4o-mini"
        end
        client
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
          user: users(:one),
          openai_client: client
        )

        assert article.persisted?
        assert_equal "Test Title", article.title
        assert_equal "Test hook.", article.parsed_fields["intro_hook"]
        assert_nil article.updated_fields
        client.verify
      end

      test "skips OpenAI and reuses parsed_fields when duplicate content_hash exists" do
        existing = Article.create!(
          title: "Original",
          original_content: "Duplicate content",
          parsed_fields: valid_parsed_data,
          fields_version: 1,
          content_hash: Digest::MD5.hexdigest("Duplicate content"),
          user: users(:one),
          status: :draft
        )

        client = Minitest::Mock.new
        # No chat expectation = if OpenAI is called, the mock will fail

        article = ParseArticleService.call(
          "Duplicate content",
          user: users(:one),
          openai_client: client
        )

        assert article.persisted?
        refute_equal existing.id, article.id, "should be a new article record"
        assert_equal existing.parsed_fields, article.parsed_fields
        assert_nil article.updated_fields
        client.verify
      end

      test "raises error for blank content" do
        assert_raises(ArgumentError, "original_content is required") do
          ParseArticleService.call("", user: users(:one))
        end
      end

      test "raises error for too-short content" do
        assert_raises(ArgumentError, "content too short to parse") do
          ParseArticleService.call("abc", user: users(:one))
        end
      end
    end
  end
end
```

- [ ] **Step 2: Run the tests**

```bash
rails test test/modules/article_ai_parser/services/parse_article_service_test.rb
```

Expected: all tests PASS.

- [ ] **Step 4: Commit**

```bash
git add test/modules/article_ai_parser/services/parse_article_service_test.rb
git commit -m "test: add ParseArticleService idempotency tests"
```

---

### Task 7: Test Serializer Merge Logic

**Files:**
- Create: `test/modules/article_management/serializers/article_serializer_test.rb`

- [ ] **Step 1: Write serializer tests**

```ruby
# test/modules/article_management/serializers/article_serializer_test.rb
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

      test "reads from parsed_fields when updated_fields is nil" do
        article = Article.new(title: "Test", parsed_fields: parsed_fields, updated_fields: nil)
        serializer = ArticleSerializer.new(article)

        assert_equal "AI intro", serializer.intro_hook
        assert_equal "everyone", serializer.best_for
      end

      test "reads from updated_fields when key exists" do
        article = Article.new(
          title: "Test",
          parsed_fields: parsed_fields,
          updated_fields: { "intro_hook" => "User edited intro" }
        )
        serializer = ArticleSerializer.new(article)

        assert_equal "User edited intro", serializer.intro_hook
        assert_equal "everyone", serializer.best_for
      end

      test "reads nil from updated_fields when key exists with nil value" do
        article = Article.new(
          title: "Test",
          parsed_fields: parsed_fields,
          updated_fields: { "intro_hook" => nil }
        )
        serializer = ArticleSerializer.new(article)

        assert_nil serializer.intro_hook
      end

      test "falls back to parsed_fields when key missing from updated_fields" do
        article = Article.new(
          title: "Test",
          parsed_fields: parsed_fields,
          updated_fields: { "best_for" => "edited" }
        )
        serializer = ArticleSerializer.new(article)

        assert_equal "AI intro", serializer.intro_hook
        assert_equal "edited", serializer.best_for
      end

      test "title is exposed directly from column" do
        article = Article.new(title: "Direct Title", parsed_fields: parsed_fields)
        serializer = ArticleSerializer.new(article)

        assert_equal "Direct Title", serializer.title
      end

      test "main_article_body falls back to empty array when nil" do
        article = Article.new(
          title: "Test",
          parsed_fields: { "title" => "AI Title" }
        )
        serializer = ArticleSerializer.new(article)

        assert_equal [], serializer.main_article_body
      end

      test "key_facts falls back to empty array when nil" do
        article = Article.new(
          title: "Test",
          parsed_fields: { "title" => "AI Title" }
        )
        serializer = ArticleSerializer.new(article)

        assert_equal [], serializer.key_facts
      end
    end
  end
end
```

- [ ] **Step 2: Run the tests**

```bash
rails test test/modules/article_management/serializers/article_serializer_test.rb
```

Expected: all tests PASS.

- [ ] **Step 3: Commit**

```bash
git add test/modules/article_management/serializers/article_serializer_test.rb
git commit -m "test: add serializer merge logic tests"
```

---

### Task 8: Update API Contract Docs

**Files:**
- Modify: `docs/api-contract.md`

- [ ] **Step 1: Update the AI Parser section to reflect idempotent behavior**

Remove the 409 duplicate response section. Add a note that duplicate content reuses existing parsed_fields without calling OpenAI. Update the article object shape to include `updated_fields`.

In the article object shape section, add:
```json
"updated_fields": null
```

Under the AI Parser section, replace the duplicate response with:
```
Duplicate content (same `content_hash`) does not call OpenAI — it reuses the existing article's `parsed_fields` and creates a new article record. No error is raised.
```

- [ ] **Step 2: Commit**

```bash
git add docs/api-contract.md
git commit -m "docs: update API contract for idempotent parser behavior"
```

---

### Task 9: Run Full Test Suite

- [ ] **Step 1: Run all tests**

```bash
rails test
```

Expected: all tests PASS (including existing article management tests).

- [ ] **Step 2: If any tests fail, fix and re-run**

Check for failing tests, fix issues, repeat until all pass.

- [ ] **Step 3: Final commit if fixes needed**

```bash
git add -A
git commit -m "fix: address test failures"
```
