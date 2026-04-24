# Phase 02 — MarkdownTextEditor
Context: [plan.md](plan.md) | [hotkey/expansion research](research/researcher-01-hotkey-and-keyword-expansion.md)

## Overview
- Date: 2026-04-24
- Description: NSViewRepresentable-wrapped NSTextView with inline keyword expansion
- Priority: P0 — hardest piece; NotesView depends on it
- Status: Not Started
- Review: Pending

## Key Insights
- **SwiftUI TextEditor is insufficient**: macOS 14 has no `TextSelection` binding; `onChange` replacement resets cursor to end. Must use NSViewRepresentable + NSTextViewDelegate.
- Keyword expansion fires in `textDidChange`: scan for trigger strings, replace in-place, restore cursor via `selectedRange`.
- `[]` and `[ ]` → `- [ ] ` (task list prefix); `::today` → formatted date string; `::tomorrow` → tomorrow's date; `::meeting`, `::slides`, `::proposal`, `::table` → SnippetStore built-in content.
- Undo: NSTextView has built-in undo manager; replacements via `insertText(_:replacementRange:)` are undo-safe (single undo step).
- Binding update: call `onTextChange` callback (not re-binding to avoid loop); parent stores to `note.body` + updates `note.updatedAt`.

## Requirements
- File: `Sources/Views/MarkdownTextEditor.swift`
- Public API: `MarkdownTextEditor(text: Binding<String>)` — SwiftUI view
- Keyword triggers: `[]`, `[ ]`, `::today`, `::tomorrow`, `::meeting`, `::slides`, `::proposal`, `::table`
- No external dependencies; no third-party libs
- Font: `.systemFont(ofSize: 13)` — matches app aesthetic

## Architecture

```
MarkdownTextEditor: NSViewRepresentable
├── @Binding var text: String
├── makeNSView(context:) → NSScrollView (wraps NSTextView)
│   └── NSTextView config: isRichText=false, font, delegate=context.coordinator
├── updateNSView(_:context:) → sync text if changed externally (guard against loop)
└── Coordinator: NSObject, NSTextViewDelegate
    ├── parent: MarkdownTextEditor
    ├── isUpdating: Bool (re-entrancy guard)
    ├── textDidChange(_:) → expandKeywords(in: textView)
    └── expandKeywords(in textView: NSTextView)
        ├── get current string + selectedRange
        ├── scan for trigger (last word before cursor)
        ├── if found: textView.insertText(replacement, replacementRange: triggerRange)
        │   └── insertText is undo-safe, moves cursor correctly
        └── push to parent.text binding via DispatchQueue.main.async (avoids re-entrancy)
```

**Keyword map** (evaluated in order, longest match first):

| Trigger | Replacement |
|---------|-------------|
| `[ ]` or `[]` | `- [ ] ` |
| `::today` | `today's date, e.g. "April 24, 2026"` |
| `::tomorrow` | tomorrow's date |
| `::meeting` | SnippetStore built-in "Meeting Notes" content |
| `::slides` | SnippetStore built-in "Slide Outline" content |
| `::proposal` | SnippetStore built-in "Proposal Structure" content |
| `::table` | SnippetStore built-in "Comparison Table" content |

## Related Code Files
- `Sources/Views/HTMLPreviewView.swift` — companion NSViewRepresentable pattern
- `Sources/Models/Snippet.swift` — SnippetStore.shared for keyword content lookup
- `Sources/Views/ContentView.swift` — shows NSViewRepresentable usage patterns

## Implementation Steps

1. Create `Sources/Views/MarkdownTextEditor.swift`

2. `makeNSView`: create `NSScrollView` + `NSTextView` (standard scroll+text setup); set `textView.delegate = context.coordinator`; disable rich text, spell-check optional, set font.

3. `updateNSView`: if `text != textView.string && !coordinator.isUpdating { textView.string = text }` — prevents binding loop.

4. `Coordinator.textDidChange`: call `expandKeywords(in:)` then update binding: `DispatchQueue.main.async { self.parent.text = textView.string }`.

5. `expandKeywords`: scan `textView.string` from position 0 to `selectedRange.location`; find last occurrence of any trigger string ending at cursor; call `textView.insertText(replacement, replacementRange: range)` — this is the single undo-safe replacement call.

6. Date formatting helper: `DateFormatter` with `dateStyle: .long, timeStyle: .none` — locale-aware.

7. SnippetStore lookup helper: `func snippetContent(for keyword: String) -> String` — searches `SnippetStore.shared.snippets` by name (case-insensitive partial match); returns content or fallback empty string.

## Todo
- [ ] Create `Sources/Views/MarkdownTextEditor.swift`
- [ ] `makeNSView` with NSScrollView + NSTextView setup
- [ ] `updateNSView` with re-entrancy guard
- [ ] `Coordinator` + `textDidChange` + `expandKeywords`
- [ ] Keyword map: `[]`/`[ ]`, `::today`, `::tomorrow`, `::meeting`, `::slides`, `::proposal`, `::table`
- [ ] SnippetStore lookup helper
- [ ] Manual smoke-test: type `::today` → expands inline, cursor after replacement, undo works
- [ ] Run `./scripts/verify_release.sh`

## Success Criteria
- Type `::today` → replaced with formatted date; cursor lands after replacement
- Type `[]` → replaced with `- [ ] `; cursor after space
- Undo (Cmd+Z) reverts expansion in one step
- Binding `text` stays in sync with NSTextView content
- No cursor jump to end on expansion

## Risk Assessment
- **High:** Re-entrancy between `textDidChange` and binding update can cause infinite loop. Mitigation: `isUpdating` flag + `DispatchQueue.main.async` deferred push.
- **Medium:** `insertText(_:replacementRange:)` moves cursor to end of inserted text — confirm this is desired behavior (yes: cursor after expansion).
- **Low:** SnippetStore built-in lookup by name is fragile if names change. Mitigation: match by `category == "Templates"` + name contains check.

## Security Considerations
- No file I/O in this layer; reads SnippetStore in-memory only
- User text is not transmitted anywhere

## Next Steps
Phase 03 — NotesView consumes `MarkdownTextEditor` as the edit pane
