# Article AI Parser Module — Design Spec

## Overview

Client sends raw text content. Server sends it to OpenAI to extract structured travel article fields and creates a draft Article.

## Module Structure

```
app/modules/article_ai_parser/
  api.rb                              # ArticleAiParser::Api
  services/
    parse_article_service.rb          # ArticleAiParser::Services::ParseArticleService
  serializers/
    article_serializer.rb             # ArticleAiParser::Serializers::ArticleSerializer
```

Dependencies: `ArticleManagement::Serializers::ArticleSerializer` (shared serializer for the Article model).

## API Endpoint

```
POST /api/v1/article_ai_parser
Content-Type: application/json

{
  "original_content": "Raw travel notes text..."
}
```

**Response 201:**
```json
{
  "id": 1,
  "title": "Komodo Boat Trip Guide",
  "status": "draft",
  "parsed_fields": { ... },
  "fields_version": 1,
  "original_content": "...",
  "content_hash": "abc123...",
  "created_at": "...",
  "updated_at": "..."
}
```

**Response 4xx/5xx:**
```json
{
  "error": "description of the problem"
}
```

## Core Service: ParseArticleService

### Input
- `original_content: String`

### Flow
1. Validate input (blank, length, encoding, duplicate hash)
2. Compute MD5 `content_hash` of `original_content`
3. Check if article with same `content_hash` exists → return 409 if yes
4. Call OpenAI chat completion with structured JSON prompt
5. Parse JSON response
6. Validate required fields (title, parsed_fields)
7. Create `Article` with:
   - `title` — from LLM response
   - `status` — `draft`
   - `original_content` — raw input
   - `parsed_fields` — full JSON from OpenAI
   - `fields_version` — 1
   - `content_hash` — MD5 hex digest
8. Return the created Article

### OpenAI Prompt

```
You are a travel article editor. Given raw travel notes, extract structured information as JSON.
Schema:
{
  "title": "string (compelling article title under 255 chars)",
  "intro_hook": "string (1-2 sentence hook to draw readers in)",
  "main_article_body": [
    { "heading": "string", "content": "string" }
  ],
  "best_for": "string (comma-separated target audience)",
  "not_for": "string (comma-separated who should skip)",
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
```

Model: `gpt-4o-mini` (low cost, fast, supports `response_format: { type: "json_object" }`)
Temperature: 0

### OpenAi Configuration

- `ruby-openai` gem
- API key from `ENV["OPENAI_API_KEY"]`
- Timeout: 30 seconds (read), 10 seconds (connect)
- Model: `gpt-4o-mini`
- `response_format: { type: "json_object" }`

## Edge Cases & Error Handling

| Condition | HTTP Code | Error Message |
|---|---|---|
| `original_content` blank/nil | 400 | "original_content is required" |
| `original_content` < 10 chars | 422 | "content too short to parse" |
| `original_content` > 100_000 chars | 422 | "content exceeds maximum length" |
| Duplicate `content_hash` | 409 | "article with this content already exists" |
| Non-UTF-8 encoding | 400 | "invalid content encoding" |
| OpenAI network/timeout | 502 | "AI service unavailable" |
| OpenAI auth error | 502 | "AI service configuration error" |
| OpenAI rate limited | 502 | "AI service rate limited. Try again later" |
| Empty/null JSON response | 502 | "AI returned empty response" |
| Invalid JSON from AI | 502 | "AI returned malformed response" |
| Missing `title` in response | 502 | "AI response missing required fields" |
| `parsed_fields` null/empty | 502 | "AI failed to extract structured data" |
| `title` blank | — | Fallback: first 50 chars of original_content |
| `title` > 255 chars | — | Truncate to 255 |

## Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount ArticleManagement::Api => "/api/v1"
  mount ArticleAiParser::Api => "/api/v1"
end
```

## Testing

- Unit test `ParseArticleService` with mocked OpenAI client
  - Success path: valid content → article created with correct fields
  - Blank content → raises `ArgumentError`
  - Short content → raises `ArgumentError`
  - Duplicate hash → raises `ActiveRecord::RecordNotUnique` or custom error
  - OpenAI network failure → raises service error
  - OpenAI returns invalid JSON → raises service error
  - OpenAI returns missing fields → raises service error
- Integration test `ArticleAiParser::Api`
  - `POST /api/v1/article_ai_parser` with valid content → 201 + article JSON
  - `POST /api/v1/article_ai_parser` with blank content → 400
  - `POST /api/v1/article_ai_parser` with duplicate → 409
  - `POST /api/v1/article_ai_parser` when OpenAI fails → 502

## Future Considerations (YAGNI — noted, not built)

- Background job for async parsing
- Batch upload via CSV/JSON
- Webhook notification on completion
- Different AI providers (Anthropic, etc.)
