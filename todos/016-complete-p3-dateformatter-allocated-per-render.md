---
name: DateFormatter allocated on every NoteRowView render
description: dateLabel, metaLabel, editedLabel all construct new DateFormatter instances per render rather than using static instances
type: todo
status: pending
priority: p3
issue_id: "016"
tags: [code-review, performance]
dependencies: []
---

## Problem Statement

`NoteRowView.dateLabel` and similar computed properties in both `NotesView` and `MinimalNotesView` create a new `DateFormatter` instance per call. `DateFormatter` is expensive to initialize (locale/calendar setup). With many notes visible in the list, this allocation runs once per row per render pass.

## Findings

**File:** `Sources/Views/NotesView.swift` lines 306–312
**File:** `Sources/Views/MinimalNotesView.swift` lines 394–407

Reported by performance-oracle.

## Proposed Solutions

### Option A — Static DateFormatter instances
```swift
private static let shortDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
}()
```
- Effort: Small | Risk: Low

## Acceptance Criteria
- [ ] DateFormatter created once per formatter type, not once per row render
- [ ] Date labels render identically to current output

## Work Log
- 2026-04-26: Identified by performance-oracle during PR #15 review
