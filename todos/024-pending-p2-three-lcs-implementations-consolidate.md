---
name: Three LCS implementations; smart mode runs up to three passes per line pair
description: TextDiff.diff, changedFlags, and lcsLength are the same recurrence three times; smartMode computes LCS length then changedFlags recomputes it; lineCount semantics duplicated in three places
type: todo
status: pending
priority: p2
issue_id: "024"
tags: [code-review, architecture, performance, diff, quality]
dependencies: []
---

## Problem Statement

Three copies of the LCS recurrence live in ClipCore: `TextDiff.diff` (TextDiff.swift:36-59), `changedFlags` (TextDiffIntraline.swift:154-173), `lcsLength` (:175-187). `lcsLength` is fully redundant: LCS length = count of unflagged tokens from `changedFlags`. In `.smart` mode the code runs char-tier `lcsLength`, possibly word-tier `lcsLength`, then `changedFlags` again on the winning tokenization — measured ~300 ms of a 424 ms full-rewrite diff spent in this layer. Any future fix (prefix/suffix trim from todo 020, tie-breaks) must be applied three times and will drift. Also `lineCount` exists byte-identical in DiffView.swift:126-128 and DiffHTMLRenderer.swift:118-120, re-encoding the "empty = 0 lines" rule that `TextDiff.lines(of:)` owns.

## Findings

Reported by: code-simplicity-reviewer, architecture-strategist, performance-oracle (P2-3, benchmarked). Also: char tokenizer allocates one heap String per grapheme (`text.map(String.init)`); `changedFlags` allocates up to 601×601 `[[Int]]` (2.9 MB) per pair.

## Proposed Solutions

### Option A — One generic LCS (recommended)
Private `lcsFlags<T: Equatable>(_:_:) -> ([Bool],[Bool])` with flat buffer. `diff` maps line flags to kinds; `changedFlags` uses directly; `smartMode` derives similarity from flag counts (kills `lcsLength`, halves smart-mode work). Add `TextDiff.lineCount(_:)` public, use from both Views files. Tokenize chars as `[Character]`.
- Effort: Medium | Risk: Low-Medium (tests cover smart-tier boundaries; note word-tier similarity basis changes slightly — whitespace-inclusive flags vs filtered LCS; thresholds have margin)
- LOC: net negative ~30

## Acceptance Criteria
- [ ] One LCS table implementation in ClipCore
- [ ] `lcsLength` removed; smart mode ≤ 2 LCS passes per pair
- [ ] All TextDiff tests pass unchanged (or threshold-only adjustments justified)
- [ ] lineCount defined once (TextDiff), used by DiffView; renderer derives counts from row data
