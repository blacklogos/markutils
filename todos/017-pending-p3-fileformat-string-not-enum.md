---
name: fileFormat stored as optional String instead of typed enum (PR #11)
description: Asset.fileFormat is String? with values "md", "txt", "json" — no compile-time safety, typo risk, no place to attach behavior
type: todo
status: pending
priority: p3
issue_id: "017"
tags: [code-review, architecture, quality]
dependencies: []
---

## Problem Statement

`Asset.fileFormat` is `String?` storing extension strings like `"md"`, `"txt"`, `"json"`. There are no compile-time exhaustiveness checks, typo risk at every call site, and no place to attach computed behavior (e.g., `isMarkdown`, display names). The field is compared directly as a string in `AssetGridView`.

## Findings

**File:** `Sources/Models/Asset.swift` line 13
**File:** `Sources/Views/AssetGridView.swift` line ~512 — direct string comparison

Reported by architecture-strategist.

## Proposed Solutions

### Option A — FileFormat enum with Codable raw value
```swift
enum FileFormat: String, Codable {
    case md, txt, json, html, csv
    var isMarkdown: Bool { self == .md }
}
// Asset:
var fileFormat: FileFormat?
```
- Pros: Compile-time safety; behavior via extensions; backward-compatible via rawValue
- Effort: Small | Risk: Low

## Acceptance Criteria
- [ ] `Asset.fileFormat` is `FileFormat?` not `String?`
- [ ] Existing assets with string-encoded format values decode correctly via `rawValue`
- [ ] All call sites use enum cases, no string comparisons

## Work Log
- 2026-04-26: Identified by architecture-strategist during PR #11 review
