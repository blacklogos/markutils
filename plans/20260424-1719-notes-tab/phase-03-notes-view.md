# Phase 03 — NotesView
Context: [plan.md](plan.md) | [panel/export research](research/researcher-02-panel-and-export.md)

## Overview
- Date: 2026-04-24
- Description: Sidebar + editor + edit/preview toggle + checkbox JS + toolbar actions
- Priority: P1 — depends on Phase 01 + 02
- Status: Not Started
- Review: Pending

## Key Insights
- Collapsible sidebar: `@State private var sidebarVisible = true` + `withAnimation` + `HSplitView` or manual `HStack` with conditional. Use `HStack` (not `HSplitView`) — simpler, more predictable in floating panel.
- Sidebar lists past notes (all notes except today) sorted by `date` descending; today's note auto-selected on appear.
- Edit/Preview toggle: `@State private var isPreview = false`. Edit = `MarkdownTextEditor`; Preview = `HTMLPreviewView(html: RichTextTransformer.markdownToHTML(note.body))`.
- Checkbox JS bridge: `HTMLPreviewView` currently has no message handler. Extend it or pass a `onCheckboxToggle` callback. Simplest: create `CheckableHTMLPreviewView` (new struct, ~30 lines) that adds `WKScriptMessageHandler` — avoids modifying shared `HTMLPreviewView`.
- Checkbox HTML: inject JS into rendered HTML that calls `window.webkit.messageHandlers.checkbox.postMessage({line: n, checked: bool})`. Handler finds `- [ ]` / `- [x]` at that line offset and toggles.
- Export via SwiftUI `.fileExporter` — macOS 14+ supported, sandbox-safe, no entitlements.
- → Transform: `MarkdownPreviewRouter.shared.request(note.body)` — existing cross-tab pattern.
- Copy: `NSPasteboard.general.clearContents(); NSPasteboard.general.setString(note.body, forType: .string)`.

## Requirements
- File: `Sources/Views/NotesView.swift`
- Left sidebar: collapsible, lists notes by date desc, tap to select
- Right editor: `MarkdownTextEditor` (edit mode) or `CheckableHTMLPreviewView` (preview mode)
- Toolbar: Copy · Export (.md / .txt) · → Transform · Edit/Preview toggle
- Checkbox toggling in preview mode updates `note.body` in place
- `@Environment(NoteStore.self)` for store access

## Architecture

```
NotesView: View
├── @Environment(NoteStore.self) var store
├── @State selectedNote: Note?        // nil = nothing selected
├── @State sidebarVisible: Bool = true
├── @State isPreview: Bool = false
├── @State isExporting: Bool = false
│
├── body: HStack
│   ├── if sidebarVisible: SidebarView (≤120px wide)
│   │   └── List of NoteRowView sorted by date desc
│   └── Divider (if sidebar visible)
│   └── EditorPane
│       ├── if !isPreview: MarkdownTextEditor(text: $selectedNote.body)
│       └── if isPreview: CheckableHTMLPreviewView(html: ..., onToggle: toggleCheckbox)
│
└── toolbar (overlay or .safeAreaInset top)
    ├── Button: sidebar toggle (chevron)
    ├── Spacer
    ├── Button: Copy
    ├── Button: Export → sets isExporting=true
    ├── Button: → Transform
    └── Toggle: Edit | Preview

NoteRowView: View
├── note: Note
├── date label (formatted) + body preview (first line, 1 line truncated)
└── background highlight if selected

CheckableHTMLPreviewView: NSViewRepresentable
├── html: String
├── onToggle: (lineIndex: Int, checked: Bool) -> Void
├── WKWebView + WKScriptMessageHandler("checkbox")
└── HTML injection: wrap rendered HTML with checkbox-click JS
```

**Checkbox JS snippet to inject** (appended before `</body>`):
```js
document.querySelectorAll('input[type=checkbox]').forEach((cb, i) => {
  cb.addEventListener('change', e => {
    window.webkit.messageHandlers.checkbox.postMessage({index: i, checked: e.target.checked})
  })
})
```
Handler in Swift: count `- [ ]` / `- [x]` occurrences in `note.body`, replace the nth occurrence.

## Related Code Files
- `Sources/Views/HTMLPreviewView.swift` — reference for WKWebView NSViewRepresentable pattern
- `Sources/Views/MarkdownTextEditor.swift` — Phase 02 output
- `Sources/Models/Note.swift` — Phase 01 output
- `Sources/MarkdownPreviewRouter.swift` — → Transform routing
- `Sources/RichTextTransformer.swift` — `markdownToHTML()` for preview

## Implementation Steps

1. Create `Sources/Views/NotesView.swift` with `NotesView` struct

2. `onAppear`: `selectedNote = store.todayNote` — auto-selects today

3. Sidebar: `ScrollView` containing `ForEach(store.notes.sorted(by: { $0.date > $1.date }))` — each row `NoteRowView`, tap sets `selectedNote`

4. Sidebar toggle: `Button` with `chevron.left` / `chevron.right`, `withAnimation(.easeInOut(duration: 0.2)) { sidebarVisible.toggle() }`

5. Editor pane: guard `selectedNote != nil` else `ContentUnavailableView`. If `!isPreview`: `MarkdownTextEditor(text: binding)` where binding reads/writes `selectedNote!.body` and sets `selectedNote!.updatedAt = Date()` on set. If `isPreview`: `CheckableHTMLPreviewView`.

6. Create `CheckableHTMLPreviewView` (NSViewRepresentable) — copy `HTMLPreviewView` setup, add `WKUserContentController.add(handler, name: "checkbox")`, inject checkbox JS before `</body>` close.

7. `toggleCheckbox(index: Int, checked: Bool)`: split `note.body` into lines, find nth checkbox line (`- [ ]` or `- [x]`), replace, rejoin, assign back to `note.body`.

8. Toolbar: `HStack` overlaid at top. Copy button calls `NSPasteboard`. Export button sets `isExporting = true`, `.fileExporter(isPresented: $isExporting, items: [exportItem], contentTypes: [.plainText])`. Transform button calls `MarkdownPreviewRouter.shared.request(note.body)`.

9. Export item: `struct NoteExportItem: FileDocument` with `init(note:)` — wraps `note.body` as `.plainText`.

## Todo
- [ ] Create `NotesView.swift` skeleton
- [ ] Sidebar with note list + date formatting
- [ ] `onAppear` selects today's note
- [ ] MarkdownTextEditor binding wired to `selectedNote.body`
- [ ] Edit/Preview toggle
- [ ] `CheckableHTMLPreviewView` with WKScriptMessageHandler
- [ ] `toggleCheckbox` line-index replacement logic
- [ ] Copy toolbar button
- [ ] Export `.fileExporter` with `NoteExportItem`
- [ ] → Transform button via `MarkdownPreviewRouter`
- [ ] Sidebar collapse animation
- [ ] Run `./scripts/verify_release.sh`

## Success Criteria
- Today's note auto-selected on tab open
- Past notes listed in sidebar, selectable
- Typing in editor persists to `NoteStore` (JSON updated)
- Preview renders markdown; checkboxes toggleable; body updates
- Copy puts note body on clipboard
- Export sheet appears; saves `.md` file
- → Transform switches to Transform tab with note content

## Risk Assessment
- **Medium:** `CheckableHTMLPreviewView` duplicates HTMLPreviewView code. Mitigation: extract ~10-line WKWebView factory func to avoid full duplication.
- **Medium:** Checkbox line-index matching is fragile if body has complex nested lists. Mitigation: count only top-level `- [ ]` / `- [x]` patterns.
- **Low:** `.fileExporter` requires `FileDocument` conformance — minor boilerplate.

## Security Considerations
- JS postMessage bridge is local-only (no external URLs loaded)
- WKWebView `setValue(false, forKey: "drawsBackground")` prevents white flash — same as HTMLPreviewView
- No network access in this view

## Next Steps
Phase 04 — NotesPanel + ⌥A hotkey (reuses NotesView in a second NSPanel)
