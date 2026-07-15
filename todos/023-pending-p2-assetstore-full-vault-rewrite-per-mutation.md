---
name: AssetStore rewrites entire vault JSON (incl. base64 image blobs) on every mutation
description: assets.didSet synchronously encodes and writes the whole vault on the main thread — 40 screenshots ≈ 107 MB JSON written per add/delete/rename
type: todo
status: pending
priority: p2
issue_id: "023"
tags: [code-review, performance, persistence]
dependencies: []
---

## Problem Statement

`assets.didSet` triggers synchronous full `JSONEncoder` encode + `data.write` on the mutating (main) thread. `imageData` lives inline and gets base64'd: 40 × 2 MB screenshots ≈ 107 MB JSON per mutation. Dragging 10 images = 10 full rewrites. Cost is linear in total vault size, so it silently degrades over months. Pre-existing.

## Findings

- `Sources/Models/AssetStore.swift:7-11,52-59` — didSet → save
- `Sources/Models/Asset.swift:10` — inline imageData

Reported by: performance-oracle (P1 in its report; P2 here — pre-existing, not merge-blocking).

## Proposed Solutions

### Option A — Coalesced background save now
didSet marks dirty; debounced background queue writes once per burst. ~20 LOC.
- Effort: Small | Risk: Low (keep atomic write; flush on terminate)

### Option B — External image files (follow-up)
Store `Clip/images/<uuid>.png`, keep references in JSON. Per-mutation cost drops to KB. Needs migration for existing vaults.
- Effort: Medium | Risk: Medium (migration)

Recommended: A now, B later.

## Acceptance Criteria
- [ ] Adding 10 images produces ≤ 2 writes, off main thread
- [ ] No data loss on quit mid-burst (flush on applicationWillTerminate)
