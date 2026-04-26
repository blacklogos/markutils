---
name: Stored XSS via unescaped note body in WKWebView
description: Note content rendered directly into <body> without HTML-escaping; JS bridge is callable from crafted note
type: todo
status: pending
priority: p1
issue_id: "002"
tags: [code-review, security]
dependencies: []
---

## Problem Statement

`CheckableHTMLPreviewView` renders user note content via `RichTextTransformer.markdownToHTML()` and injects the result directly into a `<body>` tag without prior HTML-escaping. A note body containing `<script>` tags or `<img onerror=...>` reaches the WKWebView unfiltered. The active `window.webkit.messageHandlers.checkbox` JS bridge can then be called by the injected script, mutating note state without user interaction.

## Findings

**File:** `Sources/Views/CheckableHTMLPreviewView.swift` ~line 122
```swift
// HTML built as:
<body>\(body)</body>  // body = markdownToHTML(note.body), no prior escaping
```

**File:** `Sources/ClipCore/RichTextTransformer.swift` lines 10–89, 307–324
- `parseInline()` applies regex substitutions but never HTML-escapes literal text nodes first
- Link substitution at line 311 injects raw URL into `href` without scheme validation, enabling `javascript:` URIs

**Attack vector:** A user pastes a malicious note (e.g., from clipboard), previews it, and the JS bridge fires `onToggle` with crafted data, corrupting note bodies or enabling data exfiltration via `window.location`.

Reported by security-sentinel.

## Proposed Solutions

### Option A — HTML-escape raw text before parseInline (Recommended)
Before applying any regex in `parseInline()`, escape `<`, `>`, `&`, `"`, `'` in the literal text. Then apply markdown substitutions (which produce safe HTML tags).
- Pros: Fixes root cause; standard approach
- Cons: Must be careful not to double-escape output of markdown substitutions
- Effort: Small | Risk: Low

### Option B — Add Content-Security-Policy to prevent script execution
Add `<meta http-equiv="Content-Security-Policy" content="script-src 'unsafe-inline'">` — wait, that would be wrong. Instead use `script-src 'nonce-{random}'` requiring a nonce. Combined with escaping.
- Pros: Defense in depth
- Cons: Does not fix link injection; more complex template
- Effort: Medium | Risk: Low

### Option C — Use a safe markdown library (Ink, Down, etc.)
Replace the hand-rolled regex transformer with a sandboxed CommonMark parser that outputs safe HTML by default.
- Pros: Comprehensive fix including edge cases
- Cons: Adds a dependency; diverges from current no-dependency policy
- Effort: Large | Risk: Low

## Acceptance Criteria
- [ ] `<script>alert(1)</script>` in note body renders as escaped literal text, not executed
- [ ] `[click](javascript:...)` link does not reach `href` with `javascript:` scheme
- [ ] Checkbox toggle still works after fix (JS bridge still fires on real checkboxes)
- [ ] Existing preview tests pass

## Work Log
- 2026-04-26: Identified by security-sentinel during PR #15 review
