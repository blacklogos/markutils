---
module: Clip Notes
date: 2026-06-13
problem_type: state_bug
component: frontend_appkit
symptoms:
  - "Selecting a note in the sidebar then pressing ⌥A wrote the editor's text into the previously-selected note instead of the now-open one"
  - "Opening the notes panel produced a duplicate empty note (notes.json contained 2 blank notes)"
  - "Switching notes left the editor bound to the old note, corrupting whichever note was active before the switch"
  - "An async textDidChange firing right after a note switch stamped updatedAt and persisted a no-op edit"
root_cause: stale_captured_state
resolution_type: code_fix
severity: high
tags: [swiftui, appkit, nsviewrepresentable, coordinator, stale-binding, view-identity, dot-id, nstextview, observable, debounced-save, data-corruption, notes]
---

# NSViewRepresentable: Stale Coordinator Binding Writes Into the Wrong Item on Switch

## Symptom

In the Notes feature, clicking a note in the sidebar and then pressing the ⌥A hotkey
(which opens the floating notes panel) caused two failures:

1. The editor wrote its text into the **previously-selected** note rather than the
   one now open.
2. A **duplicate empty note** was saved — confirmed by inspecting the real
   `~/Library/Application Support/Clip/notes.json`, which contained two blank notes
   dated the same day as a real note.

The corruption was silent: no error, no user signal, on a routine flow.

## Environment

- macOS 14+, Swift 5.9, SwiftUI + AppKit hybrid
- Files: `Sources/Views/MarkdownTextEditor.swift` (the `NSViewRepresentable` editor + `Coordinator`),
  `Sources/Views/NotesView.swift` and `Sources/Views/MinimalNotesView.swift` (the two editor host views),
  `Sources/Models/Note.swift` (`Note` model + `NoteStore.ensureTodayNote`)
- Fix commit: `3d63fcc`

## Root Cause

Three compounding causes:

1. **The coordinator held a stale binding.** `MarkdownTextEditor` is an
   `NSViewRepresentable` whose `Coordinator` stores `var parent: MarkdownTextEditor`,
   set once in `makeCoordinator()`/`init`. The `text` binding's `set` closure captures
   one specific `note` (`note.body = newBody; note.updatedAt = Date()`). When SwiftUI
   re-rendered with a *different* note's binding, `updateNSView` never re-pointed
   `context.coordinator.parent` at the new render's `self`. So `textDidChange` kept
   calling `self.parent.text = newText` through the original closure — writing the
   editor's contents into the **first** note selected when the view was created.

2. **The editor was reused across note switches, and `textDidChange` writes asynchronously.**
   Without a stable SwiftUI identity, switching notes reused the same
   `NSTextView`/`Coordinator` instance instead of rebuilding it. Combined with the
   deferred write in `textDidChange`:

   ```swift
   let newText = textView.string
   DispatchQueue.main.async { [weak self] in
       self?.parent.text = newText
   }
   ```

   a pending `DispatchQueue.main.async` write enqueued just before a note switch
   landed *after* the switch — stamping the wrong note's `body`/`updatedAt` (and
   persisting it). The deferred hop is what let the write outlive the selection that
   produced it.

3. **`ensureTodayNote` appended a second today-note.** Pressing ⌥A opens the panel,
   which calls `ensureTodayNote()`. The old implementation matched only the *first*
   today-note (`notes.first(where:)`). Edge timing — or a blank just created by a prior
   open — meant a fresh `Note()` was appended again, stacking an empty duplicate for the
   same day. Repeated opens kept piling up blanks.

## Failed / Partial Approaches

A first attempt at cause #3 made `ensureTodayNote` reuse **any** empty note regardless
of day (reusing a leftover blank from a previous day instead of creating today's note).
This was wrong — it broke the test asserting that opening the panel on a new day creates
a note dated today, and it would have resurfaced stale notes from prior days. The fix was
corrected to be **today-scoped**: filter to today's notes only, and among those pick the
**most recently updated** one — so legacy duplicate blanks on disk resolve to the note
the user actually touched, while a genuinely new day still gets a fresh note.

## Solution

**1. `MarkdownTextEditor.updateNSView` re-points the coordinator's `parent` every render**
(`Sources/Views/MarkdownTextEditor.swift`):

```swift
// BEFORE
func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let textView = scrollView.documentView as? NSTextView else { return }
    guard !context.coordinator.isUpdating, textView.string != text else { return }
    textView.string = text
    ...
}

// AFTER
func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let textView = scrollView.documentView as? NSTextView else { return }
    // Re-point the coordinator at THIS render's binding.
    context.coordinator.parent = self
    guard !context.coordinator.isUpdating, textView.string != text else { return }
    textView.string = text
    ...
}
```

**2. Both notes views give the editor a stable per-note identity and ignore no-op writes**
(`Sources/Views/NotesView.swift` and `Sources/Views/MinimalNotesView.swift`):

```swift
// BEFORE
MarkdownTextEditor(text: Binding(
    get: { note.body },
    set: { newBody in
        note.body = newBody
        note.updatedAt = Date()
        NoteStore.shared.save()
    }
))

// AFTER
MarkdownTextEditor(text: Binding(
    get: { note.body },
    set: { newBody in
        guard newBody != note.body else { return }   // drop async no-op writes after a switch
        note.body = newBody
        note.updatedAt = Date()
        NoteStore.shared.save()
    }
))
.id(note.id)   // rebuild the editor per note — clean coordinator, no pending edits
```

The `.id(note.id)` forces SwiftUI to tear down and recreate the editor on selection
change (no inherited coordinator or queued write), and the `guard newBody != note.body`
discards the stray deferred `textDidChange` write that would otherwise only bump
`updatedAt`.

**3. `ensureTodayNote` reuses the most-recently-edited today-note instead of appending**
(`Sources/Models/Note.swift`):

```swift
// BEFORE
func ensureTodayNote() -> Note {
    if let existing = notes.first(where: { Calendar.current.isDateInToday($0.date) }) {
        return existing
    }
    let note = Note()
    notes.append(note)
    return note
}

// AFTER
func ensureTodayNote() -> Note {
    let todays = notes.filter { Calendar.current.isDateInToday($0.date) }
    if let today = todays.max(by: { $0.updatedAt < $1.updatedAt }) {
        return today
    }
    let note = Note()
    notes.append(note)
    return note
}
```

## Prevention

### 1. NSViewRepresentable + per-item bindings: refresh the coordinator AND key the view by identity

A `Coordinator` is created once in `makeCoordinator()` and reused for the lifetime of the
representable. When the binding's setter closure captures per-item state (a specific
`Note`), the coordinator holds the binding from *first creation* and writes edits into the
wrong item after a switch. Always do **both**:

- In `updateNSView`, re-point the coordinator at the current render: `context.coordinator.parent = self`.
- Give the representable a stable `.id(item.id)` keyed to item identity. Switching items
  then tears down and rebuilds the NSView + coordinator, so no stale text, pending async
  write, or delegate state leaks across items.

Either alone is insufficient: `.id()` without the `parent =` refresh still risks an
in-flight write landing on the old target; the refresh without `.id()` reuses
`NSTextView` state across items.

### 2. Closure-captured bindings + deferred (async) writes: guard no-ops and stale targets

`textDidChange` dispatches `parent.text = newText` async, so a write can land *after* the
user has switched items. Defend at the setter:

- Bail on no-op writes: `guard newBody != note.body else { return }`. Prevents an
  unchanged async callback from stamping `updatedAt` and triggering a spurious save.
- Never let a deferred write blindly mutate + persist. Only stamp `updatedAt`/`save()` on
  a genuine value change; treat the captured target as potentially stale.

### 3. "Ensure singleton-per-day" factories: dedupe and reuse, never blindly append

`ensureTodayNote()` must *find-or-create*, not append:

- Filter for today's existing items first; if any exist, **return** one (prefer the
  most-recently-edited via `.max(by: { $0.updatedAt < $1.updatedAt })`) so repeated opens
  land on the active note, not a stale blank.
- Only `append` a fresh item when none exists for the day.
- Be resilient to legacy data: if duplicates already sit on disk, resolve to a single
  sensible item rather than compounding the problem.

### Regression coverage & manual check

Tests in `Tests/ClipTests/NoteStoreTests.swift` (74 passing, +2):

- `testEnsureTodayNoteReusesExistingTodayNoteInsteadOfStackingBlanks` — seeds one real
  today-note, calls `ensureTodayNote()` twice, asserts the same id is returned and exactly
  one today-note exists (the ⌥A / panel-reopen duplicate repro).
- `testEnsureTodayNotePrefersMostRecentlyEditedTodayNote` — with a stale blank + a recent
  edited note both dated today, asserts the factory returns the recently-edited one.

Manual check (catches the NSViewRepresentable-level corruption the unit tests can't reach):
open the panel repeatedly, switch between notes via the sidebar and ⌥A, type in a few, then
decode `~/Library/Application Support/Clip/notes.json` and count notes with
empty/whitespace-only `body`. There should be zero stray empty notes, and edits must appear
in the note focused when typed — never in the previously-selected one.

## Related

- [`docs/solutions/ui-bugs/clear-background-no-hit-area-swiftui-rows-20260426.md`](clear-background-no-hit-area-swiftui-rows-20260426.md)
  — Closest sibling: same module (Clip Notes), same two files (`NotesView.swift`,
  `MinimalNotesView.swift`), another SwiftUI Notes-sidebar pitfall. The `.id(note.id)` fix
  here lives in those exact files.
- [`docs/solutions/ui-bugs/nscolor-dynamic-provider-light-dark-20260405.md`](nscolor-dynamic-provider-light-dark-20260405.md)
  — Same SwiftUI/AppKit-bridge category; a "works in `View` context, breaks in
  static/non-reactive context" failure mode, conceptually parallel to "Coordinator captured
  a stale binding and never re-read it."
- [`docs/solutions/security-issues/xss-wkwebview-markdown-parseinline-html-escape-swift.md`](../security-issues/xss-wkwebview-markdown-parseinline-html-escape-swift.md)
  — Same Notes rendering pipeline (`NoteStore` → `markdownToHTML()` → `WKWebView`) and
  overlapping files; cross-reference for the data-flow chain the editor feeds into.
- [`docs/solutions/best-practice/swift-cli-target-isolation-observable-pattern-20260408.md`](../best-practice/swift-cli-target-isolation-observable-pattern-20260408.md)
  — Background on the `@Observable` macro backing the `NoteStore`/`Note` model layer.

**Cross-reference commits:** `50155ef` (original Notes-tab feature) · `009cca9` (Reader tab;
renamed `todayNote` → `ensureTodayNote`) · `d87dc2a` (checkbox `data-line` rework, same files)
· `3d63fcc` (**this fix**).

**Apple docs:**
- [`NSViewRepresentable.updateNSView(_:context:)`](https://developer.apple.com/documentation/swiftui/nsviewrepresentable/updatensview(_:context:)) — the hook that must re-point the Coordinator's captured binding each render (cause #1).
- [`NSViewRepresentable.makeCoordinator()`](https://developer.apple.com/documentation/swiftui/nsviewrepresentable/makecoordinator()) — Coordinator lifetime; why it holds a stale `parent` across updates.
- [`View.id(_:)`](https://developer.apple.com/documentation/swiftui/view/id(_:)) — stable identity to force a fresh editor on switch (cause #2).
- [`@Observable`](https://developer.apple.com/documentation/observation/observable()) — model mutation behavior backing `NoteStore`/`Note`.
