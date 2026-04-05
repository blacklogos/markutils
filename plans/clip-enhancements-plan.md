# Clip Enhancement Plan

## Context
Tri is primary user. Workflow: marketing tasks — markdown, tables, reports, slides, proposals. No AI needed now. Goal: make Clip a fast, reliable daily-driver utility.

---

## Phase 1: Core UX Fixes (Quick Wins)

### 1.1 Global Hotkey (Cmd+Shift+C)
- **File**: `Sources/AppDelegate.swift`
- **What**: Register global hotkey via `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)` to toggle floating panel
- **Default**: `Cmd+Shift+C` (configurable later via UserDefaults)
- **Edge case**: Check for conflicts with other apps. If key combo already taken, silently skip (don't crash)
- **Acceptance**: Press hotkey from any app → panel toggles

### 1.2 Resizable Window + Tab Icons
- **Files**: `Sources/ClipApp.swift`, `Sources/Views/ContentView.swift`
- **What**:
  - Remove `.fixedSize()` and `.windowResizability(.contentSize)` from ClipApp
  - Set minimum size (450x400) via FloatingPanel `minSize`
  - Save/restore frame position with `UserDefaults` (or NSPanel's built-in `setFrameAutosaveName`)
  - Replace text tab labels with SF Symbols: `square.grid.2x2` (Assets), `arrow.left.arrow.right` (Transform), `textformat` (Text Formatter), `doc.text` (Snippets)
  - Add `.help()` tooltips for each icon
- **Acceptance**: Window resizes freely, remembers size/position across launches. Tab icons are clear at any width.

### 1.3 Asset Search & Filter
- **File**: `Sources/Views/AssetGridView.swift`
- **What**:
  - Add `@State private var searchText = ""` 
  - Add `TextField` with magnifying glass icon in toolbar row
  - Filter `assets` computed property: match against `name` and `textContent` (case-insensitive)
  - Show "No results" when filter returns empty but vault has items
- **Acceptance**: Type "logo" → only assets with "logo" in name/content shown. Clear search → all assets back.

### 1.4 Asset Rename
- **File**: `Sources/Views/AssetGridView.swift` (both `AssetItemView` and `CompactAssetRowView`)
- **What**:
  - Double-click asset name → inline `TextField` for editing
  - `@State private var isRenaming = false` + `@State private var editName = ""`
  - On submit: update `asset.name`, store auto-saves via `didSet`
  - Escape key cancels rename
- **Acceptance**: Double-click "Pasted Image" → type "Client Logo" → Enter → name persists.

---

## Phase 2: Transform Power-Ups

### 2.1 Drag-Out Rich Text from Preview
- **Files**: `Sources/Views/TransformerView.swift`, `Sources/Utilities/RichTextTransformer.swift`
- **What**:
  - Wrap the preview pane in `.onDrag { }` 
  - Create `NSItemProvider` with RTF data: convert HTML output → NSAttributedString → RTF via `NSAttributedString.data(from:documentAttributes:)` with `documentType: .rtf`
  - Also register plain text fallback
- **Acceptance**: Write markdown in Transform tab → drag preview pane into Keynote/Pages/Mail → formatted text appears with bold/italic/headers intact.

### 2.2 Quick Actions / Unified Input (Evolve Transform Tab)
- **File**: New `Sources/Views/QuickActionsView.swift`, modify `Sources/Views/ContentView.swift`
- **What**:
  - Replace Transform tab content with a unified input:
    1. Single text input area (current editor)
    2. Auto-detect content type on paste/type (reuse existing smart detection logic)
    3. Show action buttons below input based on detected type:
       - Markdown detected → "Preview", "To HTML", "To Rich Text", "Copy HTML"
       - Table detected → "To Markdown Table", "To CSV", "To TSV"
       - Plain text → "To Bullet List", "To Numbered List", "Format for Social"
    4. Output area shows result, with copy + drag-out buttons
  - Keep the existing `TransformerView` logic internally — this is a UI layer on top, not a rewrite
  - Detection logic: check for `|` + `-` pattern (table), `#` / `**` / `- ` (markdown), `\t` (TSV)
- **Acceptance**: Paste a markdown table → buttons show "To CSV" / "To TSV". Paste markdown text → buttons show "Preview" / "To HTML". No manual mode switching needed.

---

## Phase 3: Productivity Features

### 3.1 Clipboard History
- **File**: New `Sources/Services/ClipboardMonitor.swift`, modify `Sources/Views/AssetGridView.swift`
- **What**:
  - New service: poll `NSPasteboard.general.changeCount` every 1s via Timer
  - On change: capture text/image from pasteboard, save as Asset with `name: "Clipboard [timestamp]"`
  - Cap at 50 items. Auto-prune oldest when exceeded.
  - Toggle on/off via menu bar menu (new "Clipboard History: On/Off" item in AppDelegate menu)
  - Store toggle state in UserDefaults
  - Visual: clipboard items show a clock icon badge in AssetGridView to distinguish from manual imports
- **Acceptance**: Copy text in Safari → switch to Clip → clipboard item appears in Assets automatically. Toggle off → stops capturing.

### 3.2 Snippets / Templates Tab (Replace AI Tab)
- **Files**: New `Sources/Views/SnippetsView.swift`, new `Sources/Models/Snippet.swift`, modify `Sources/Views/ContentView.swift`
- **What**:
  - `Snippet` model: `id`, `name`, `content` (markdown string), `category` (optional)
  - Store as JSON in App Support (same pattern as AssetStore)
  - Tab 3 (replace AI): list of snippets with search
  - Click snippet → copies to clipboard + shows "Copied" feedback
  - "+" button → create new snippet (name + content editor)
  - Long-press or right-click → edit / delete
  - Ship with built-in templates:
    - "Meeting Notes" (date, attendees, agenda, action items)
    - "Slide Outline" (title, sections with bullets)  
    - "Proposal Structure" (exec summary, problem, solution, timeline, pricing)
    - "Comparison Table" (markdown table template)
  - Built-in templates are read-only but can be duplicated
- **Acceptance**: Click "Proposal Structure" → full template in clipboard → paste into any app. Create custom snippet "Email Signature" → always one click away.

### 3.3 macOS Service Integration ("Open in Clip")
- **File**: `Sources/AppDelegate.swift`, `Info.plist` (or Package.swift metadata)
- **What**:
  - Register `NSApp.servicesProvider` with a method like `transformInClip(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>)`
  - When invoked: read text from pasteboard, open Clip panel, paste into Transform input, auto-detect type
  - Register in `NSServices` key in Info.plist with `NSMenuItem` title "Transform in Clip"
- **Caveat**: SPM-built executables don't have a standard Info.plist flow. May need to embed via a script or switch to Xcode project for this feature. **Evaluate feasibility first** before committing.
- **Acceptance**: Select text in any app → right-click → Services → "Transform in Clip" → Clip opens with text loaded.

---

## Phase Summary

| Phase | Features | Estimated Scope |
|-------|----------|----------------|
| 1 | Global hotkey, resize window, tab icons, search, rename | Small changes, independent of each other |
| 2 | Drag-out rich text, Quick Actions unified input | Medium — builds on existing Transform logic |
| 3 | Clipboard history, Snippets tab, macOS Service | New services and models, largest changes |

## File Changes Overview

| File | Changes |
|------|---------|
| `Sources/AppDelegate.swift` | Global hotkey, clipboard toggle menu, services provider |
| `Sources/ClipApp.swift` | Remove fixed size constraints |
| `Sources/Views/ContentView.swift` | Tab icons, swap AI tab → Snippets |
| `Sources/Views/AssetGridView.swift` | Search field, rename on double-click |
| `Sources/Views/AssetItemView.swift`* | Rename UI (if extracted) |
| `Sources/Views/TransformerView.swift` | Drag-out rich text |
| `Sources/Views/QuickActionsView.swift` | NEW — unified paste-and-detect UI |
| `Sources/Views/SnippetsView.swift` | NEW — snippets/templates tab |
| `Sources/Models/Snippet.swift` | NEW — snippet data model |
| `Sources/Services/ClipboardMonitor.swift` | NEW — pasteboard polling service |

*Consider extracting `AssetItemView` and `CompactAssetRowView` from `AssetGridView.swift` into separate files during Phase 1 — that file is already 611 lines.

## Dependencies Between Features
- Phase 1 items are fully independent — can be done in any order or in parallel
- 2.1 (drag-out) is independent of 2.2 (Quick Actions)
- 2.2 (Quick Actions) replaces the Transform tab UI but reuses all existing transformer logic
- 3.1 (clipboard) depends on 1.3 (search) being done first — otherwise vault floods with unsearchable items
- 3.2 (snippets) depends on 1.2 (tab icons) — need the AI tab slot freed up
- 3.3 (macOS service) is independent but may require build system changes

## Risks
- **macOS Service (3.3)**: SPM doesn't natively support Info.plist NSServices. May need workaround or defer.
- **Clipboard history (3.1)**: 1s polling timer is cheap but runs forever. Must stop when app quits. Test memory with large image captures.
- **Quick Actions detection (2.2)**: Ambiguous content (is `- item` a markdown list or just text with a dash?) — keep manual override available as fallback.
