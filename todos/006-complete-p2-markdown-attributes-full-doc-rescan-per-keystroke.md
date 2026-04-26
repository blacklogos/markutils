---
name: applyMarkdownAttributes rescans full document on every keystroke
description: 6 full-document regex passes fire on each NSTextStorageDelegate edit event; O(6n) per character typed
type: todo
status: pending
priority: p2
issue_id: "006"
tags: [code-review, performance]
dependencies: []
---

## Problem Statement

`MarkdownTextEditor.Coordinator` implements `NSTextStorageDelegate.textStorage(_:didProcessEditing:range:changeInLength:)`. On every `.editedCharacters` event it calls `applyMarkdownAttributes(to:)`, which resets the full document's attributes then runs 6 separate `enumerateMatches` regex passes over the entire string. For a 5,000-word note this causes millions of character comparisons per second of fast typing.

## Findings

**File:** `Sources/Views/MarkdownTextEditor.swift` lines 118–124 (delegate fires on every edit)
**File:** `Sources/Views/MarkdownTextEditor.swift` lines 128–181 (`applyMarkdownAttributes` — 6 full sweeps)
**File:** `Sources/Views/MarkdownTextEditor.swift` lines 239–244 (static regexes — compiled once, correct)

The static regex compilation is already optimized. The problem is purely the full-range reset + 6 full sweeps per keystroke.

Reported by performance-oracle.

## Proposed Solutions

### Option A — Dirty-paragraph approach (Recommended)
Expand `editedRange` to paragraph boundaries using `NSString.paragraphRange(for:)`, then re-style only that range.
```swift
let paraRange = (storage.string as NSString).paragraphRange(for: editedRange)
applyMarkdownAttributes(to: storage, in: paraRange)
```
Handles all inline patterns (bold, italic, code, strike) correctly since they cannot span paragraphs. Headings/blockquotes are paragraph-level so also covered.
- Pros: ~95% reduction in work for typical edits; no behavioral change
- Effort: Small | Risk: Low

### Option B — Full-document rescan throttled to 100ms
Debounce `applyMarkdownAttributes` with a 100ms timer; skip intermediate calls.
- Pros: Trivial to implement
- Cons: Styling lags; visible flicker on fast typing
- Effort: Small | Risk: Medium

## Acceptance Criteria
- [ ] Typing in a 500-line note shows no style-lag or flicker
- [ ] Heading, bold, italic, code, strikethrough, blockquote all still render correctly
- [ ] Multi-line constructs (if any) still highlighted

## Work Log
- 2026-04-26: Identified by performance-oracle during PR #15 review
