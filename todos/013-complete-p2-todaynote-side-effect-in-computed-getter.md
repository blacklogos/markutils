---
name: todayNote computed property mutates state and triggers I/O as a side effect
description: NoteStore.todayNote creates and persists a new Note when called; called from onAppear in two views — mutation inside a getter is an architectural smell
type: todo
status: pending
priority: p2
issue_id: "013"
tags: [code-review, architecture]
dependencies: []
---

## Problem Statement

`NoteStore.todayNote` is a `var` computed property that calls `add(_ note:)` and writes to disk when no today-note exists. It is called from `onAppear` in both `NotesView` and `MinimalNotesView`. Computed getters are expected to be read-only; callers and SwiftUI tooling may call them multiple times. Mutation in a getter is surprising and makes the API unsafe to use in `map`, `filter`, or other functional contexts.

## Findings

**File:** `Sources/Models/Note.swift` lines 62–69
```swift
var todayNote: Note {
    if let existing = notes.first(where: { Calendar.current.isDateInToday($0.date) }) {
        return existing
    }
    let note = Note()
    add(note)  // <-- side effect: mutates notes + triggers save()
    return note
}
```

**File:** `Sources/Views/NotesView.swift` line 40 — called in `onAppear`
**File:** `Sources/Views/MinimalNotesView.swift` line 61 — called in `onAppear`

Reported by architecture-strategist.

## Proposed Solutions

### Option A — Rename to ensureTodayNote() function (Recommended)
```swift
@discardableResult
func ensureTodayNote() -> Note {
    if let existing = notes.first(where: { Calendar.current.isDateInToday($0.date) }) {
        return existing
    }
    let note = Note()
    notes.append(note)
    return note
}
```
Call once from a coordinator `onAppear`, not from two views independently.
- Pros: Makes mutation intent explicit; function vs. property distinction is idiomatic Swift
- Effort: Small | Risk: Low

## Acceptance Criteria
- [ ] `todayNote` getter removed or made purely read-only
- [ ] `ensureTodayNote()` called exactly once on app launch (not twice from two views)
- [ ] Behavior unchanged: today's note is always available when either view opens

## Work Log
- 2026-04-26: Identified by architecture-strategist during PR #15 review
