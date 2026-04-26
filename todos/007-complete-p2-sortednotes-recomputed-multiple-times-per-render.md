---
name: sortedNotes computed property called 4-5x per SwiftUI render pass
description: MinimalNotesView recomputes sorted+filtered notes list in multiple independent computed properties per render cycle
type: todo
status: pending
priority: p2
issue_id: "007"
tags: [code-review, performance]
dependencies: []
---

## Problem Statement

In `MinimalNotesView`, `sortedNotes` is a computed property (not cached) that calls `store.notes.sorted(...)` on every access. `filteredNotes` calls `sortedNotes` and then `filter`. Both are also called independently from `hasPrev`, `hasNext`, `currentIndex`, and the bottom bar rendering — meaning a single search keystroke triggers 4–5 separate sort+filter passes over the full notes array.

## Findings

**File:** `Sources/Views/MinimalNotesView.swift` lines 302–307
```swift
var sortedNotes: [Note] { store.notes.sorted { $0.date > $1.date } }
var filteredNotes: [Note] { sortedNotes.filter { ... } }
var hasPrev: Bool { currentIndex > 0 }  // calls filteredNotes
var hasNext: Bool { ... }               // calls filteredNotes
var currentIndex: Int? { filteredNotes.firstIndex { ... } }
```

Each property independently recomputes the sort. With 1,000 notes: ~4,000–5,000 comparisons per render.

Same pattern exists in `NotesView.swift` line 128 sidebar computed property.

Reported by performance-oracle.

## Proposed Solutions

### Option A — Compute once in body, pass down (Recommended)
In `body`, compute `let notes = filteredNotes` once, then pass to sub-views and derived values:
```swift
var body: some View {
    let notes = filteredNotes  // sorted once
    let idx = notes.firstIndex { $0.id == selectedNoteID }
    ...
}
```
- Pros: Zero redundant sorts; works within SwiftUI's declarative model
- Effort: Small | Risk: Low

### Option B — Cache in @State
Store sorted+filtered result in `@State var cachedNotes: [Note]`, update via `.onChange(of: searchQuery)`.
- Pros: Explicit cache invalidation
- Cons: More state to manage; must also invalidate when `store.notes` changes
- Effort: Medium | Risk: Low

## Acceptance Criteria
- [ ] `sortedNotes` sort called at most once per render pass
- [ ] `hasPrev`/`hasNext`/`currentIndex` derive from same pre-sorted array
- [ ] Profiler shows no redundant sort calls on search keystroke

## Work Log
- 2026-04-26: Identified by performance-oracle during PR #15 review
