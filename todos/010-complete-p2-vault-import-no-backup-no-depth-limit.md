---
name: Vault import overwrites assets.json without backup or depth guard
description: importVault() immediately replaces the live vault with no atomic write, no backup, and no recursive depth limit on imported JSON
type: todo
status: pending
priority: p2
issue_id: "010"
tags: [code-review, security, architecture]
dependencies: []
---

## Problem Statement

`AppDelegate.importVault()` decodes user-selected JSON directly as `[Asset]` and assigns it to `AssetStore.shared.assets`, triggering an immediate `save()` that overwrites `assets.json`. There is no backup of the existing vault before replacement, no atomic rename pattern, and no guard against deeply-nested `children` arrays that could exhaust stack or memory during decode.

## Findings

**File:** `Sources/AppDelegate.swift` lines 292–319

Steps taken by the current implementation:
1. Open NSOpenPanel → user selects a file
2. `JSONDecoder().decode([Asset].self, from: data)` — unbounded recursion via `children`
3. `AssetStore.shared.assets = imported` — overwrites in-memory state
4. `didSet { save() }` immediately writes to disk, destroying previous vault

No error recovery path after step 3 fails partway through. No backup written before step 3.

Reported by security-sentinel.

## Proposed Solutions

### Option A — Atomic write + backup (Recommended)
```swift
// 1. Write imported data to assets.json.import-tmp
// 2. Rename existing assets.json → assets.json.bak
// 3. Rename assets.json.import-tmp → assets.json
// 4. Update in-memory state
```
- Pros: Recoverable on failure; standard atomic-write pattern
- Effort: Small | Risk: Low

### Option B — Add depth limit to Asset.init(from:)
Override `init(from:)` to track nesting depth, throwing `DecodingError` beyond depth 20.
- Pros: Prevents DoS via malformed import
- Cons: Doesn't protect against vault overwrite after successful decode
- Effort: Small | Risk: Low

### Option C — Both A and B
- Effort: Small | Risk: Low

## Acceptance Criteria
- [ ] Import failure (malformed JSON) leaves original vault intact
- [ ] Previous vault backed up to `.bak` before replacement
- [ ] Deeply nested JSON (depth 50+) is rejected, not decoded
- [ ] Success confirmation shown to user after safe import

## Work Log
- 2026-04-26: Identified by security-sentinel during PR #15 review
