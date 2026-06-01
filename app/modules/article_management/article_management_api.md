# Article Management API

Base path depends on the Grape mount point (e.g., `/api/v1/article_management`).

## Endpoints

### 1. List Articles

```
GET /article_management
```

**Query parameters:**

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `status` | String | No | Filter by status. Values: `draft`, `reviewed`, `published` |

**Response `200 OK`:**
```json
[
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
]
```

---

### 2. Get Single Article

```
GET /article_management/:id
```

**Path parameters:**

| Param | Type | Required |
|-------|------|----------|
| `id` | Integer | Yes |

**Response `200 OK`:** Single article object (same shape as list item).

**Response `404 Not Found`:**
```json
{ "error": "Couldn't find Article with 'id'=999" }
```

---

### 3. Update Article

```
PUT /article_management/:id
```

**Path parameters:**

| Param | Type | Required |
|-------|------|----------|
| `id` | Integer | Yes |

**Request body (JSON):**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | String | No | Article title |
| `intro_hook` | String | No | Hook/intro sentence |
| `main_article_body` | Array | No | Array of heading/content sections |
| `best_for` | String | No | Who this is best for |
| `not_for` | String | No | Who this is not for |
| `ethics_safety_notes` | String | No | Ethics and safety notes |
| `key_facts` | Array | No | Array of label/value pairs |

**Sample request:**
```json
{
  "title": "Discover the Magic of Paris: A Springtime Adventure",
  "intro_hook": "Experience the enchanting beauty of Paris in spring...",
  "main_article_body": [
    { "heading": "The Eiffel Tower: A Nighttime Spectacle", "content": "..." }
  ],
  "best_for": "art lovers, foodies, couples",
  "not_for": "budget travelers",
  "ethics_safety_notes": "Always be aware of your surroundings...",
  "key_facts": [
    { "label": "Eiffel Tower Sparkle", "value": "Every hour at night" }
  ]
}
```

**Response `200 OK`:** Full updated article object.

**Response `400 Bad Request`:**
```json
{ "error": "..." }
```

**Response `404 Not Found`:**
```json
{ "error": "Couldn't find Article with 'id'=..." }
```

---

### 4. Change Article Status

```
PATCH /article_management/:id/status
```

**Path parameters:**

| Param | Type | Required |
|-------|------|----------|
| `id` | Integer | Yes |

**Request body (JSON):**

| Field | Type | Required | Values |
|-------|------|----------|--------|
| `status` | String | Yes | `draft`, `reviewed`, `published` |

**Valid status transitions:**

| Current Status | Can transition to |
|----------------|-------------------|
| `draft` | `reviewed` |
| `reviewed` | `draft`, `published` |
| `published` | `reviewed` |

**Response `200 OK`:** Full updated article object.

**Response `400 Bad Request`:**
```json
{ "error": "Cannot transition from 'draft' to 'published'" }
```

**Response `404 Not Found`:**
```json
{ "error": "Couldn't find Article with 'id'=..." }
```

---

## Common Response Shape

Every endpoint returns the article object in this format:

```json
{
  "title": "string",
  "intro_hook": "string or null",
  "main_article_body": [
    { "heading": "string", "content": "string" }
  ],
  "best_for": "string or null",
  "not_for": "string or null",
  "ethics_safety_notes": "string or null",
  "key_facts": [
    { "label": "string", "value": "string" }
  ]
}
```
