---
name: UnicodeTextFormatter.convertInline recompiles 7 regexes per line
description: 500-line MD→Unicode conversion = ~3500 NSRegularExpression compiles; hoist to static lets
type: todo
status: pending
priority: p3
issue_id: "030"
tags: [code-review, performance, formatter]
dependencies: []
---

## Problem Statement / Findings

`Sources/ClipCore/UnicodeTextFormatter.swift:330-345` — `convertInline` constructs 7 `NSRegularExpression`s per invocation, called once per line by `markdownToUnicode`. Button-triggered (not per keystroke), impact tens of ms per click on large documents.

Reported by: performance-oracle (P3-3). Same agent cleared the NFD-per-character path in applyAccent as fine (only non-ASCII map misses hit it).

## Proposed Solutions

Hoist the 7 patterns into `static let` compiled regexes (same for regexApplyLink's pattern).
- Effort: Small | Risk: Low

## Acceptance Criteria
- [ ] No NSRegularExpression init inside convertInline call path
- [ ] Existing formatter tests pass
