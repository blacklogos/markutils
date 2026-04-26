---
name: NotesView and MinimalNotesView duplicate CRUD logic and double-save on text edit
description: 742 lines of two views that share selection, delete, copy, ephemeral message, and onAppear logic; MinimalNotesView double-saves on text edit
type: todo
status: pending
priority: p2
issue_id: "011"
tags: [code-review, architecture, quality]
dependencies: []
---

## Problem Statement

`NotesView` (313 lines) and `MinimalNotesView` (429 lines) both reimplement: note selection state, sorted/filtered list, new-note creation with guard, delete-with-confirmation, copy-to-clipboard, ephemeral status message, and `onAppear` today-note seeding. Any feature added to one must be duplicated in the other.

Additionally, `MinimalNotesView` line 94 calls `NoteStore.shared.save()` explicitly in a binding setter, but `note.body` mutation already causes a save path elsewhere — resulting in a double disk write per text change.

## Findings

**File:** `Sources/Views/NotesView.swift` lines 152–180 — note editing binding, save, ephemeral message
**File:** `Sources/Views/MinimalNotesView.swift` lines 88–100 — same binding, explicit `save()` call (double-save)
**File:** `Sources/Views/NotesView.swift` lines 196–226 — createNewNote, confirmAndDeleteNote
**File:** `Sources/Views/MinimalNotesView.swift` lines 210–240 — same functions duplicated

Reported by architecture-strategist and performance-oracle.

## Proposed Solutions

### Option A — Extract NoteEditorViewModel (Recommended)
```swift
@Observable class NoteEditorViewModel {
    var selectedNote: Note?
    var searchQuery: String = ""
    var bottomMessage: String?
    func createNewNote() { ... }
    func confirmAndDeleteNote(_ note: Note) { ... }
    func copyCurrentNote() { ... }
    var filteredNotes: [Note] { ... }  // computed once
}
```
Both views become thin wrappers differing only in chrome (toolbar vs. minimal bars), sharing the same ViewModel instance via environment.
- Pros: Single source of truth; fixes double-save; easier to test
- Effort: Medium | Risk: Low

### Option B — Shared internal View components
Extract `NoteRowView` customization and action handlers as shared internal components without a full ViewModel.
- Pros: Less structural change
- Cons: Still duplicated state; doesn't fix double-save
- Effort: Small | Risk: Medium

## Acceptance Criteria
- [ ] Double-save on text edit eliminated (one write per text change)
- [ ] CRUD operations (create, delete, copy) implemented in one place
- [ ] Both views remain functionally identical to current behavior

## Work Log
- 2026-04-26: Identified by architecture-strategist and performance-oracle during PR #15 review
