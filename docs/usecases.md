# AI Editorial Assistant — Core Use Cases

## UC-01 Create New Article

### Description

User creates a new travel article draft by uploading a `.docx` file containing rough travel experience notes.

### Flow

* User clicks "Create New Article"
* User uploads `.docx` file
* User clicks submit

### Result

A new article draft generation process is started.

---

# UC-02 Generate Structured Draft Article

### Description

After document submission, the backend extracts the raw content and sends it to OpenAI API for structured parsing.

### Parsed Fields

* Title
* Intro / hook
* Main article body
* Best for
* Not for
* Ethics / safety notes
* Key facts

### Backend Responsibilities

* Extract content from `.docx`
* Call OpenAI API
* Parse response into fixed structured fields
* Store:

  * original content
  * structured parsed content
  * article status

### Initial Status

`draft`

### Result

A structured draft article is successfully generated and stored.

---

# UC-03 View Draft Articles

### Description

Generated articles are displayed in the article list page.

### Display Fields

* Title
* Status
* Created at
* Updated at

### Result

User can browse existing articles and open them for review.

---

# UC-04 Edit And Review Article

### Description

User opens a draft article and edits generated fields before publishing.

### Editable Fields

* Title
* Intro / hook
* Main article body
* Best for
* Not for
* Ethics / safety notes
* Key facts

### Available Statuses

* `draft`
* `reviewed`
* `published`

### Actions

* Update article content
* Change article status
* Save article updates

### Result

Article content and review status are updated successfully.
