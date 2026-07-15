---
name: Diff preview fully reloads WKWebView per change, resetting scroll
description: Every keystroke rebuilds ~1 MB of row HTML on the main thread and loadHTMLString reparses the document and jumps scroll to top
type: todo
status: complete
priority: p1
issue_id: "021"
tags: [code-review, performance, diff, ux]
dependencies: ["020"]
---

## Problem Statement

Every content change rebuilds the full rows HTML (one div per diff line; 1 MB+ at 4000 lines) and calls `loadHTMLString`, which reparses everything and resets scroll to top. Scenario: scroll to line 3000, fix a typo in Revised, preview jumps to top after the 020 stall.

## Findings

- `Sources/Views/DiffView.swift:31-33` — HTML rebuilt per body eval
- `Sources/Views/HTMLPreviewView.swift:18-25` — identical-content guard exists but any real change reloads
- `Sources/Views/DiffHTMLRenderer.swift:10-27` — row assembly on main thread

Reported by: performance-oracle (P1).

## Proposed Solutions

### Option A — Incremental innerHTML update
Keep page loaded; replace only `.split` contents via `evaluateJavaScript`. Build HTML off-main together with the 020 debounced diff.
- Pros: no reparse, scroll preserved naturally
- Effort: Medium | Risk: Medium (JS string size limits — chunk if needed)

### Option B — Capture/restore scrollY around reload
Smallest fix: read `window.scrollY` before `loadHTMLString`, restore in `didFinish`.
- Pros: tiny; Cons: still full reparse cost
- Effort: Small | Risk: Low

## Acceptance Criteria
- [ ] Scroll position survives edits to either pane
- [ ] No visible flash on update
