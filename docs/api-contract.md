# API Contract

**Base URLs:**
- Auth: `http://localhost:4567/api`
- Articles & AI Parser: `http://localhost:4567/api/v1`

**Auth:** All endpoints except `POST /api/auth/login` require an `Authorization: Bearer <token>` header.

---

## Auth

### `POST /api/auth/login`

Register or login by name. Returns the same token on subsequent calls.

**Request:**
```json
{ "name": "Nhan" }
```

**Response `200`:**
```json
{ "access_token": "de392db34a1df39bd85c843ba3c912108b0558be2390cbdff887a355e6a09401" }
```

**Response `400` (missing name):**
```json
{ "error": "name is missing" }
```

**Response `400` (blank name):**
```json
{ "error": "name is required" }
```

---

## Articles

All endpoints require `Authorization: Bearer <token>`.

### Article object shape

Returned by list, get, create, update, and status change endpoints.

```json
{
  "id": 1,
  "title": "Discover the Magic of Paris",
  "status": "draft",
  "parsed_fields": null,
  "fields_version": 1,
  "original_content": "Paris was amazing...",
  "content_hash": "c16b88f9c02575d0de27aceafaadb126",
  "user_id": 1,
  "created_at": "2026-06-01T17:43:37.406Z",
  "updated_at": "2026-06-01T17:43:37.406Z"
}
```

When `status` is `draft` and created via the AI parser, `parsed_fields` is a JSON object:

```json
{
  "title": "Discover the Magic of Paris: A Springtime Adventure",
  "intro_hook": "Experience the enchanting beauty of Paris in spring...",
  "main_article_body": [
    { "heading": "The Eiffel Tower: A Nighttime Spectacle", "content": "..." },
    { "heading": "Culinary Delights in Montmartre", "content": "..." }
  ],
  "best_for": "art lovers, foodies, couples, history enthusiasts",
  "not_for": "budget travelers, those seeking solitude, people averse to crowds",
  "ethics_safety_notes": "Always be aware of your surroundings...",
  "key_facts": [
    { "label": "Eiffel Tower Sparkle", "value": "Every hour at night" },
    { "label": "Best Season to Visit", "value": "Spring" }
  ]
}
```

### `GET /api/v1/article_management`

List articles, newest first.

**Query params:** `?status=draft` (optional, filters by status)

**Response `200`:** Array of article objects.

### `GET /api/v1/article_management/:id`

Get a single article.

**Response `200`:** Article object.

**Response `404`:**
```json
{ "error": "Couldn't find Article with 'id'=999" }
```

### `PUT /api/v1/article_management/:id`

Update article fields.

**Request:** All fields optional.
```json
{
  "title": "New Title",
  "parsed_fields": "{...}",
  "original_content": "Updated text",
  "content_hash": "abc123"
}
```

**Response `200`:** Updated article object.

### `PATCH /api/v1/article_management/:id/status`

Change article status (state machine: `draft` ↔ `reviewed` → `published`).

**Request:**
```json
{ "status": "reviewed" }
```

**Response `200`:** Updated article object.

**Response `400` (invalid transition):**
```json
{ "error": "cannot transition from reviewed to draft" }
```

---

## AI Parser

### `POST /api/v1/article_ai_parser`

Send raw travel notes, get back a structured draft article.

**Request:**
```json
{ "original_content": "Paris was amazing..." }
```

**Response `200`:** Article object with full `parsed_fields`.

**Response `400` (validation):**
```json
{ "error": "original_content is required" }
```

**Response `502` (OpenAI error):**
```json
{
  "error": "AI service error: the server responded with status 401 for POST ...",
  "details": "You didn't provide an API key..."
}
```

---

## Common Errors

| Status | Body |
|--------|------|
| `401` | `{ "error": "Unauthorized" }` |
| `404` | `{ "error": "Couldn't find Article..." }` |
| `502` | `{ "error": "AI service error: ...", "details": "..." }` |
