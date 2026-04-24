# Phase 05 — ContentView Wiring + Cleanup
Context: [plan.md](plan.md) | [scout report](scout/scout-01-codebase-report.md)

## Overview
- Date: 2026-04-24
- Description: Replace Tab 3 (Snippets→Notes), widen picker, remove SnippetStore @State, delete SnippetsView.swift
- Priority: P1 — depends on Phase 03
- Status: Not Started
- Review: Pending

## Key Insights
- `ContentView.swift` change is surgical: 4 targeted edits + 1 file delete
- `SnippetStore` import must be KEPT (keyword expansion in Phase 02 reads it) — only the `@State` + `.environment()` injection is removed
- Picker width 180 → 220 to fit 4 icons without crowding
- Tab 3 icon: `square.and.pencil` (spec); current Tab 3 uses `doc.text`
- `SnippetStore.shared` is a singleton — no environment injection needed in NoteStore; NotesView uses `@Environment(NoteStore.self)` injected from AppDelegate (same pattern as AssetStore)
- After removing `@State private var snippetStore`, also remove the `.environment(snippetStore)` modifier on `SnippetsView()`

## Requirements
- `ContentView.swift`: swap Tab 3 content + icon, widen picker, remove snippetStore @State + environment
- `NoteStore.shared` injected in `AppDelegate.createFloatingPanel()` via `.environment(NoteStore.shared)`
- Delete `Sources/Views/SnippetsView.swift`
- No other files changed in this phase

## Architecture

**ContentView.swift diff (conceptual):**

```swift
// REMOVE
@State private var snippetStore = SnippetStore.shared

// CHANGE picker width
.frame(width: 180)  →  .frame(width: 220)

// CHANGE Tab 3 icon + label
Image(systemName: "doc.text").tag(3).help("Snippets")
→
Image(systemName: "square.and.pencil").tag(3).help("Notes")

// CHANGE case 3 body
case 3:
    SnippetsView()
        .environment(snippetStore)
→
case 3:
    NotesView()
```

**AppDelegate.createFloatingPanel() diff:**

```swift
// CHANGE
let viewWithModel = AnyView(contentView.environment(AssetStore.shared))
→
let viewWithModel = AnyView(
    contentView
        .environment(AssetStore.shared)
        .environment(NoteStore.shared)
)
```

## Related Code Files
- `Sources/Views/ContentView.swift` — primary edit target (lines 10, 43–44, 82–84)
- `Sources/AppDelegate.swift` — add NoteStore environment (line 110)
- `Sources/Views/SnippetsView.swift` — DELETE
- `Sources/Views/NotesView.swift` — Phase 03 output, referenced here

## Implementation Steps

1. **ContentView.swift edits** (in order to avoid line-shift confusion):
   a. Remove `@State private var snippetStore = SnippetStore.shared` (line 10)
   b. Change `.frame(width: 180)` → `.frame(width: 220)` on the Picker
   c. Change `Image(systemName: "doc.text").tag(3).help("Snippets")` → `Image(systemName: "square.and.pencil").tag(3).help("Notes")`
   d. Replace `case 3:` body: remove `SnippetsView().environment(snippetStore)`, insert `NotesView()`

2. **AppDelegate.swift edit**: in `createFloatingPanel()`, chain `.environment(NoteStore.shared)` after `.environment(AssetStore.shared)`.

3. **Delete** `Sources/Views/SnippetsView.swift`:
   ```bash
   rm Sources/Views/SnippetsView.swift
   ```

4. **Verify build**: `swift build` — confirm no unresolved identifier errors for `snippetStore` or `SnippetsView`.

5. Run `./scripts/verify_release.sh`.

## Todo
- [ ] Remove `@State private var snippetStore = SnippetStore.shared` from ContentView
- [ ] Widen picker `.frame(width: 220)`
- [ ] Update Tab 3 icon: `square.and.pencil`, help: "Notes"
- [ ] Replace `case 3:` with `NotesView()`
- [ ] Add `.environment(NoteStore.shared)` in AppDelegate `createFloatingPanel()`
- [ ] Delete `Sources/Views/SnippetsView.swift`
- [ ] `swift build` clean
- [ ] Run `./scripts/verify_release.sh`

## Success Criteria
- Tab 3 shows Notes icon + NotesView content
- No compile errors referencing `SnippetsView` or `snippetStore`
- `SnippetStore` still importable (keyword expansion works)
- Picker displays 4 icons without visual crowding at 220px
- `./scripts/verify_release.sh` passes

## Risk Assessment
- **Low:** Removing `snippetStore` @State breaks environment injection — mitigated by NoteStore injection in AppDelegate and SnippetStore singleton access in MarkdownTextEditor (no environment needed).
- **Low:** File delete is irreversible without git. Mitigation: commit before delete; `SnippetsView.swift` recoverable from git history.
- **Low:** Picker width 220 may look cramped at small panel widths. Current min width is 450px — 220px picker is ~49% of min width, acceptable.

## Security Considerations
- No new surface area — pure refactor/wiring phase

## Next Steps
All phases complete → run full `./scripts/verify_release.sh` → manual smoke test of all 4 tabs + ⌥A hotkey
