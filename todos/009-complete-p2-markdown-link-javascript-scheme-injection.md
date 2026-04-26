---
name: Markdown link renderer injects raw URL into href — javascript: scheme executable
description: RichTextTransformer embeds unvalidated URLs from note content into <a href> without scheme check; javascript: URIs run in the WKWebView
type: todo
status: pending
priority: p2
issue_id: "009"
tags: [code-review, security]
dependencies: ["002"]
---

## Problem Statement

`RichTextTransformer.parseInline()` converts `[text](url)` markdown links to `<a href="$2">` without validating the URL scheme. A note containing `[click](javascript:window.webkit.messageHandlers.checkbox.postMessage({idx:0,checked:true}))` will produce a clickable link that invokes the JS bridge, corrupting note state.

## Findings

**File:** `Sources/ClipCore/RichTextTransformer.swift` line 311
```swift
result = result.replacingOccurrences(
    of: "\\[([^\\]]+)\\]\\(([^)]+)\\)",
    with: "<a href=\"$2\" target=\"_blank\">$1</a>", ...)
```
`$2` is the raw URL from the note — no scheme validation.

Related to finding 002 (XSS). This todo can be resolved alongside 002 but is a distinct injection vector.

Reported by security-sentinel.

## Proposed Solutions

### Option A — Allowlist http/https schemes only (Recommended)
After regex substitution, scan for any `href` values and strip non-http(s) schemes:
```swift
// Replace href values that are not http:// or https://
result = result.replacingOccurrences(
    of: " href=\"(?!https?://)([^\"]*)\"",
    with: " href=\"#\"", options: .regularExpression)
```
- Pros: Simple additive fix; safe default
- Effort: Small | Risk: Low

### Option B — Validate URL in capture group before substitution
Use a `NSRegularExpression.enumerateMatches` pass to validate group 2 before substituting.
- Pros: More precise
- Cons: More complex regex logic
- Effort: Medium | Risk: Low

## Acceptance Criteria
- [ ] `[click](javascript:...)` renders as non-executable link
- [ ] `[click](https://example.com)` still opens correctly
- [ ] No regression in existing HTML preview tests

## Work Log
- 2026-04-26: Identified by security-sentinel during PR #15 review
