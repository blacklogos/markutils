---
name: Diff preview HTML is a full document nested inside another document
description: DiffHTMLRenderer and tooLargeHTML call MarkdownPreviewStyle.page(), then HTMLPreviewView wraps in page() again — WebView receives <body><!DOCTYPE html>… and renders only because WebKit repairs it
type: todo
status: pending
priority: p1
issue_id: "019"
tags: [code-review, quality, diff, uncommitted]
dependencies: []
---

## Problem Statement

`DiffHTMLRenderer.html()` (lines 12, 26) and `DiffView.tooLargeHTML` (line ~131) return complete `<!DOCTYPE html>` documents via `MarkdownPreviewStyle.page(body:)`. `HTMLPreviewView.fullHTML` (HTMLPreviewView.swift:7-9) wraps its input in `page()` again. The Diff tab therefore loads a document nested inside a document, with the ~4 KB stylesheet twice and the copy `<script>` at the parser's mercy. It renders only because WebKit hoists/repairs illegal tags. Every other caller (QuickActionsView:219) passes body fragments — that is the contract.

In the uncommitted diff work; fix before committing this branch.

## Findings

- `Sources/Views/DiffHTMLRenderer.swift:12,26` — `page()` calls in renderer
- `Sources/Views/DiffView.swift:~131` — `tooLargeHTML` also wraps
- `Sources/Views/HTMLPreviewView.swift:7-9` — the single legitimate wrap point

Reported by: code-simplicity-reviewer, architecture-strategist (P1), performance-oracle (P2 — double stylesheet inflates every reload).

## Proposed Solutions

### Option A — Return body fragments (recommended)
Delete the two `MarkdownPreviewStyle.page` calls in DiffHTMLRenderer and one in `tooLargeHTML`; return the fragment. HTMLPreviewView remains the only wrap point.
- Pros: ~6 LOC, restores contract, removes latent parser dependency
- Effort: Small | Risk: Low (visual check of Diff tab after)

## Acceptance Criteria
- [ ] DiffHTMLRenderer returns body-only HTML (no DOCTYPE/html/head)
- [ ] tooLargeHTML returns a fragment
- [ ] Diff tab renders identically (headers, colors, copy buttons work)
- [ ] `swift build` clean
