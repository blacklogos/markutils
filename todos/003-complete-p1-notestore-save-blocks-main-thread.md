---
name: NoteStore.save() blocks main thread on every keystroke
description: Synchronous JSONEncoder + file write fires on every note body character typed, degrading typing responsiveness
type: todo
status: pending
priority: p1
issue_id: "003"
tags: [code-review, performance]
dependencies: []
---

## Problem Statement

`NoteStore.save()` runs `JSONEncoder().encode(notes)` then `data.write(to: fileURL)` synchronously. The binding setter in both `NotesView` and `MinimalNotesView` calls `NoteStore.shared.save()` directly inside the `set` closure on the main actor. This means every character typed triggers a blocking JSON encode + disk write on the main thread. At modest note sizes this is imperceptible, but degrades linearly with vault size.

## Findings

**File:** `Sources/Models/Note.swift` lines 79–86 — `save()` is synchronous
**File:** `Sources/Views/NotesView.swift` lines 152–157 — `save()` called in binding setter
**File:** `Sources/Views/MinimalNotesView.swift` lines 91–95 — `save()` called directly in binding setter (double-save: also triggers `notes.didSet`)

Additionally, `MinimalNotesView` line 94 calls `NoteStore.shared.save()` explicitly, which doubles the save: `note.body` mutation doesn't fire `notes.didSet` (elements of @Observable array don't re-fire array's didSet), but the explicit call still runs a full encode+write in addition to whatever path `NotesView` takes.

Reported by performance-oracle.

## Proposed Solutions

### Option A — Background Task + debounce 300ms (Recommended)
Replace synchronous `save()` with a debounced async save:
```swift
private var saveTask: Task<Void, Never>?
func scheduleSave() {
    saveTask?.cancel()
    saveTask = Task {
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled else { return }
        await saveToDisk()
    }
}
@MainActor private func saveToDisk() {
    // encode + write on background thread via Task.detached
}
```
- Pros: Zero main-thread I/O; 300ms debounce collapses burst keystrokes to single write
- Cons: Slightly more complex; last-write must still happen on app termination
- Effort: Small | Risk: Low

### Option B — DispatchQueue async
Move encode+write to `DispatchQueue(label: "notestore.save", qos: .utility).async { ... }`.
- Pros: Simple, familiar pattern
- Cons: No debouncing; still writes on every keystroke, just off main thread
- Effort: Small | Risk: Low

### Option C — Keep sync but debounce only
Throttle `save()` calls to at most once per 500ms using a `Timer`. Keep sync I/O.
- Pros: Minimal change
- Cons: Still blocks main thread if save happens to fire; harder to reason about
- Effort: Small | Risk: Medium

## Acceptance Criteria
- [ ] Typing at >10 WPM in a large (50KB+) note shows no UI jank
- [ ] App termination (`applicationWillTerminate`) flushes any pending save synchronously
- [ ] No data loss between last keystroke and quit
- [ ] Double-save at MinimalNotesView:94 eliminated

## Work Log
- 2026-04-26: Identified by performance-oracle during PR #15 review
