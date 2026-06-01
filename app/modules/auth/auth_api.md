# Auth API

## Login / Register

```
POST /auth/login
```

**Request body (JSON):**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | String | Yes | User display name |

**Response `200 OK`:**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiJ9..."
}
```

The `access_token` is a JWT (HS256) containing `username`, `user_id`, and `iat` (issued at). Use it in subsequent requests via the `Authorization: Bearer <token>` header.

**Response `400 Bad Request`:**
```json
{ "error": "name is required" }
```

**Response `409 Conflict`:**
```json
{ "error": "..." }
```
