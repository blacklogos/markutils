# Phase 01 — Data Layer
Context: [plan.md](plan.md) | [scout report](scout/scout-01-codebase-report.md)

## Overview
- Date: 2026-04-24
- Description: Note model + NoteStore singleton + unit tests
- Priority: P0 — all other phases depend on this
- Status: Not Started
- Review: Pending

## Key Insights
- Mirror `Snippet.swift` pattern exactly: `@Observable final class`, explicit `CodingKeys`, eager `didSet { save() }`
- `Note` has no `isBuiltIn` / `category` — simpler than Snippet
- `todayNote` computed property must auto-create + persist on first access (side effect in computed = must call `add()`)
- Day comparison: strip time via `Calendar.current.isDateInToday(_:)` — do NOT compare raw Date values
- JSON path: `~/Library/Application Support/Clip/notes.json` — same `Clip` dir, `AssetStore` already creates it

## Requirements
- `Note`: `id UUID`, `body String`, `date Date` (creation day), `updatedAt Date` — Codable, Identifiable, `@Observable`
- `NoteStore`: `@Observable` singleton, `notes: [Note]` with eager save, load on init
- `todayNote: Note` — computed, finds today's note or creates one via `add()`; never returns nil
- No search, tags, folders

## Architecture

```
Sources/Models/Note.swift
├── Note (@Observable, Identifiable, Codable)
│   ├── id: UUID
│   ├── body: String          // markdown content
│   ├── date: Date            // day of creation (store full timestamp, compare by day)
│   └── updatedAt: Date       // mutated on body change
└── NoteStore (@Observable, singleton)
    ├── static let shared
    ├── notes: [Note] { didSet { save() } }
    ├── var todayNote: Note   // find or create
    ├── func add(_ note: Note)
    ├── func save()           // private, JSONEncoder → notes.json
    └── func load()           // private, JSONDecoder ← notes.json
```

## Related Code Files
- `Sources/Models/Snippet.swift` — direct pattern reference
- `Sources/AppDelegate.swift` — shows `applicationSupportDirectory` path setup
- `Tests/ClipTests/` — test target location

## Implementation Steps

1. Create `Sources/Models/Note.swift`
   - `@Observable final class Note: Identifiable, Codable` with explicit `CodingKeys`
   - `init(body: String = "")` sets `id = UUID()`, `date = Date()`, `updatedAt = Date()`
   - No custom encode/decode needed beyond explicit CodingKeys (same as Snippet pattern)

2. Add `NoteStore` in same file (same pattern as `SnippetStore`)
   - `fileURL` points to `.../Clip/notes.json`
   - `private init()` calls `load()`; does NOT seed built-ins
   - `todayNote`: `if let n = notes.first(where: { Calendar.current.isDateInToday($0.date) }) { return n }`; else create, `add()`, return

3. Write unit tests `Tests/ClipTests/NoteStoreTests.swift`
   - Test: `todayNote` creates note on empty store
   - Test: calling `todayNote` twice returns same instance (no duplicate creation)
   - Test: `body` mutation updates `updatedAt`
   - Test: encode/decode round-trip preserves all fields

## Todo
- [ ] Create `Sources/Models/Note.swift` with `Note` + `NoteStore`
- [ ] `todayNote` computed property with auto-create
- [ ] Unit tests in `Tests/ClipTests/NoteStoreTests.swift`
- [ ] Run `./scripts/verify_release.sh`

## Success Criteria
- `swift build` clean
- `swift test` — all NoteStore tests pass
- `NoteStore.shared.todayNote` returns a note; calling twice returns same note
- JSON file written to correct path on first access

## Risk Assessment
- **Medium:** `@Observable` + `Codable` requires explicit `CodingKeys` — missing any key causes silent decode failure. Mitigation: copy Snippet pattern exactly.
- **Low:** `didSet { save() }` on `notes` array fires on every `append` during `load()`. Mitigation: set `notes` via direct assignment only in `load()` (same as SnippetStore).

## Security Considerations
- JSON written to user's own Application Support dir — no sandbox concern
- No sensitive data; notes are user-authored plain text

## Next Steps
Phase 02 — MarkdownTextEditor (consumes `NoteStore.shared.todayNote.body`)
