---
name: Note.swift manual Codable implementation is unnecessary
description: @Observable does not conflict with synthesized Codable; manual CodingKeys + init(from:) + encode(to:) are 100% identical to compiler-generated code
type: todo
status: pending
priority: p3
issue_id: "014"
tags: [code-review, quality]
dependencies: []
---

## Problem Statement

`Note` manually implements `CodingKeys`, `init(from decoder:)`, and `encode(to encoder:)`. All four property names (`id`, `body`, `date`, `updatedAt`) match their raw string keys exactly — meaning the compiler would generate identical code. The manual implementation adds ~19 lines of noise and maintenance burden with no benefit.

## Findings

**File:** `Sources/Models/Note.swift` lines 20–38
```swift
enum CodingKeys: String, CodingKey {
    case id, body, date, updatedAt
}
required init(from decoder: Decoder) throws { ... }
func encode(to encoder: Encoder) throws { ... }
```

Note: `AssetStore` requires manual Codable due to `@Observable` macro issues (documented in CLAUDE.md). `Note` was written to match that pattern even though it doesn't need to.

Reported by code-simplicity-reviewer.

## Proposed Solutions

### Option A — Remove manual Codable, keep `Codable` conformance
Delete lines 20–38, keep `final class Note: Identifiable, Codable`. Verify with `swift build`.
- Effort: Small | Risk: Low

## Acceptance Criteria
- [ ] `swift build` succeeds without manual Codable
- [ ] Existing NoteStore JSON round-trips correctly (notes persisted before and after change decode cleanly)
- [ ] NoteStoreTests pass

## Work Log
- 2026-04-26: Identified by code-simplicity-reviewer during PR #15 review
