# Notes Tab — Implementation Plan
Date: 2026-04-24 | App: Clip macOS

## Overview
Replace Tab 3 (Snippets) with a daily-notes editor. Persistent per-day notes, NSTextView-based keyword expansion, Edit/Preview toggle, collapsible sidebar, second NSPanel, ⌥A global hotkey.

Tab order after: Assets(0) · Transform(1) · Social(2) · Notes(3)

## Phases

| # | Phase | Status | File |
|---|-------|--------|------|
| 1 | Data Layer (Note + NoteStore + tests) | Complete | [phase-01-data-layer.md](phase-01-data-layer.md) |
| 2 | MarkdownTextEditor (NSViewRepresentable + keyword expansion) | Complete | [phase-02-markdown-text-editor.md](phase-02-markdown-text-editor.md) |
| 3 | NotesView (sidebar + editor + preview + toolbar) | Complete | [phase-03-notes-view.md](phase-03-notes-view.md) |
| 4 | NotesPanel + ⌥A hotkey | Complete | [phase-04-notes-panel-and-hotkey.md](phase-04-notes-panel-and-hotkey.md) |
| 5 | ContentView wiring + cleanup | Complete | [phase-05-content-view-wiring.md](phase-05-content-view-wiring.md) |

## Dependency Order
Phase 1 → Phase 2 → Phase 3 → Phase 4 + Phase 5 (parallel)

## Files Created / Modified / Deleted

**New:**
- `Sources/Models/Note.swift`
- `Sources/Views/NotesView.swift`
- `Sources/Views/MarkdownTextEditor.swift`
- `Sources/NotesPanel.swift`

**Modified:**
- `Sources/Views/ContentView.swift`
- `Sources/AppDelegate.swift`

**Deleted:**
- `Sources/Views/SnippetsView.swift`

## Validation
Run `./scripts/verify_release.sh` after each phase.

---

## Decisions

1. **Hotkey mechanism** — `NSEvent.addGlobalMonitorForEvents` (not CGEventTap). Consistent with existing Cmd+Shift+C pattern, no new entitlement. ⌥A dedicated to NotesPanel only.
2. **Checkbox JS bridge** — create `CheckableHTMLPreviewView` separately; do not modify shared `HTMLPreviewView`.
3. **NotesPanel window level** — `.floating`; user can unpin via pin button.
4. **Keyword template content** — insert verbatim body from matching `SnippetStore` built-in.
