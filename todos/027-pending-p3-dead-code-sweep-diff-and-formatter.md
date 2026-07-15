---
name: Dead code sweep — diff pipeline and formatter leftovers
description: isIdentical (O(n·m) equivalent of a == b, zero prod callers), styleMap unreachable branch, unused Precision conformances, dead iso8601 line, dual clipboard strategies
type: todo
status: pending
priority: p3
issue_id: "027"
tags: [code-review, quality, cleanup]
dependencies: []
---

## Problem Statement / Findings

Verified-by-grep dead or redundant code (~35 LOC total):
- `TextDiff.isIdentical` (TextDiff.swift:64-66): zero production callers (tests only); mathematically equal to `a == b` at O(n·m) cost. Remove + its test asserts.
- `Precision: String, CaseIterable` (TextDiffIntraline.swift:15): no rawValue/allCases use anywhere. Drop to bare enum.
- `styleMap` unreachable branch (UnicodeTextFormatter.swift:175): `.underline/.strikethrough` intercepted in `apply` before reaching it; `styleMap` has one caller — inline it.
- `encoder.dateEncodingStrategy = .iso8601` (ClipCLI/main.swift:333): encoder then encodes `[String: String]`, dates pre-formatted. Dead line.
- Dual clipboard strategies in copyScript (DiffHTMLRenderer.swift:94-105): async clipboard unreliable in `loadHTMLString(baseURL: nil)` webview; execCommand fallback must work anyway. Keep only fallback.
- Note (defer): SocialMediaFormatterView.swift holds 3 types at 404 lines — split MacEditorView out next time the file is touched.

Reported by: code-simplicity-reviewer (all verified with grep), architecture-strategist, performance-oracle (isIdentical: measured 128 ms on identical 4000-line texts).

## Proposed Solutions

One sweep commit, run tests + verify Diff tab copy buttons still work after clipboard simplification.
- Effort: Small | Risk: Low

## Acceptance Criteria
- [ ] All five removals applied; `swift build` clean; tests pass
- [ ] Copy buttons in Diff tab still copy (fallback path)
