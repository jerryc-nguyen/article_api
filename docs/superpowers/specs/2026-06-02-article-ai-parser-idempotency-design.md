# Article AI Parser Idempotency — Design Spec

**Date:** 2026-06-02

## Summary

Make `POST /api/v1/article_ai_parser` idempotent with respect to OpenAI calls. When the same `original_content` is uploaded again, skip the AI call and reuse the existing AI-parsed data. Introduce an `updated_fields` column to separate AI-generated content from user edits.

## Changes

### 1. Database Migration

Add a nullable `updated_fields` text column (serialized JSON) to `articles`.

```ruby
add_column :articles, :updated_fields, :text
```

No default, no null constraint. `nil` means "no user edits yet."

`parsed_fields` becomes write-once from this point forward (set during initial creation, never modified by updates).

No data migration — existing articles keep their current `parsed_fields` as-is.

### 2. ParseArticleService — Idempotent Duplicate Handling

- Remove `check_duplicate!` (which raised `RecordNotUnique`)
- On duplicate `content_hash`:
  - Find the existing article with that hash
  - **Skip the OpenAI call entirely**
  - Create a new article record copying the existing article's `parsed_fields`
  - New article gets `updated_fields: nil`
- On no duplicate: call OpenAI and create a new article (same as today)

The response always returns the newly created article.

### 3. UpdateArticle — Write Edits to `updated_fields`

- On update, write user-modified parsed fields into `updated_fields` instead of `parsed_fields`
- `title` remains a direct column (unchanged)
- A field set to explicit `nil` stores `nil` in `updated_fields` (the key exists, indicating explicit intent)
- `PARSED_FIELDS` list stays the same: `intro_hook, main_article_body, best_for, not_for, ethics_safety_notes, key_facts`

```ruby
updates = (article.updated_fields || {}).deep_symbolize_keys
PARSED_FIELDS.each { |key| updates[key] = attrs.delete(key) if attrs.key?(key) }
update_attrs[:updated_fields] = updates if updates.present?
article.update!(update_attrs)
```

### 4. Serializer — Merged View

Each parsed field first checks `updated_fields`. If the key exists (even with a nil value), use it; otherwise fall back to `parsed_fields`:

```ruby
if article.updated_fields&.key?("intro_hook")
  article.updated_fields["intro_hook"]
else
  article.parsed_fields&.dig("intro_hook")
end
```

Applied to: `intro_hook`, `main_article_body`, `best_for`, `not_for`, `ethics_safety_notes`, `key_facts`.

`title` is a direct column — unaffected.

### 5. Test Plan

- **UpdateArticleTest:** Assert writes go to `updated_fields`, not `parsed_fields`; nil writes nil; title stays direct.
- **ParseArticleServiceTest (new):** Duplicate hash skips OpenAI, creates new article with same parsed_fields; non-duplicate calls OpenAI.
- **ArticleSerializerTest (new):** No updated_fields → parsed_fields; key in updated_fields → merged value; nil key → nil; title unaffected.
