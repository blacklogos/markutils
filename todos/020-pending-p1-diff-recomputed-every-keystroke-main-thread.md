---
name: Diff LCS recomputed synchronously in body on every keystroke
description: TextDiff.annotatedDiff runs inside DiffView.body per keystroke — measured 2.8 s/keystroke debug (175 ms release) at the 4000-line cap, 128 MB DP table allocated and freed each time
type: todo
status: pending
priority: p1
issue_id: "020"
tags: [code-review, performance, diff]
dependencies: []
---

## Problem Statement

`DiffView.swift:17-18` runs `TextDiff.annotatedDiff` inside `body`, re-executing on every keystroke in either TextEditor, every precision change, and every split-divider drag tick. Benchmarked against real ClipCore code (~10% lines edited): 1000 lines = 308 ms debug / 25 ms release per keystroke; 4000 lines = 2752 ms debug / 175 ms release. `verify_release.sh` builds debug, so debug numbers are what runs locally. The 4000-line cap prevents hangs, not jank. DP table at cap: 4001×4001 Ints ≈ 128 MB as nested arrays, allocated per evaluation.

## Findings

- `Sources/Views/DiffView.swift:17-18` — compute in body
- `Sources/ClipCore/TextDiff.swift:36-45` — `[[Int]]` DP table, String comparisons
- `Sources/Views/DiffView.swift:126-128` — lineCount also scans both full strings per eval (fold in)

Reported by: performance-oracle (P1, benchmarked), architecture-strategist (P2).

## Proposed Solutions

### Option A — Trim + debounce + background (recommended, do all three)
1. Trim common prefix/suffix lines before LCS — a single keystroke changes ~1 line, table collapses from 4000² to ~1².
2. Move compute to a debounced (~200 ms) background `Task` keyed on `(original, revised, precision)`; store `[AnnotatedLine]` in `@State`.
3. Intern lines to Int ids and use one flat `[Int]` buffer instead of `[[Int]]`.
- Pros: typing becomes near-free; one ~100 ms recompute after a paste
- Effort: Medium | Risk: Medium (async state, cancellation; tests exist for engine behavior)

### Option B — Trim only
Prefix/suffix trim in `TextDiff.diff`. Smallest change, fixes the common case, still synchronous on paste.
- Effort: Small | Risk: Low

## Acceptance Criteria
- [ ] Typing in a 2000-line diff shows no visible stall (debug build)
- [ ] Diff output identical for existing test suite
- [ ] No diff computation inside `body`
