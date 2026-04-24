# Scout Report: Notes Tab Feature Implementation
**Date:** 2026-04-24  
**Scope:** Codebase patterns for Notes tab feature analysis

---

## Architecture Overview

**Clip** is a macOS 14+ accessory app with a floating panel UI. Tab-based architecture with environment injection for shared state. Five tabs currently: Assets (0), Transform (1), Text Formatter (2), Snippets (3), and empty slot for Notes (4).

---

## File Summaries

### AppDelegate.swift
- **Status Item Setup:** `NSStatusBar.systemStatusItem()` with paperclip icon, left-click toggles panel, right-click shows menu
- **Window Management:** `FloatingPanel` created in `createFloatingPanel()`, size 550x750, delegates to AppDelegate for close-button handling
- **Global Hotkey:** Cmd+Shift+C (keyCode 8) monitored via `NSEvent.addGlobalMonitorForEvents()`, calls `togglePanel()`
- **Key Pattern:** Single-instance enforcement via `checkSingleInstance()` using bundle ID check
- **Data Export/Import:** JSON encoder/decoder for vault backup with `AssetStore.shared.assets` — model for data persistence pattern

### FloatingPanel.swift
- **NSPanel Subclass:** Init takes `contentRect`, `backing`, `defer` — passes styleMask with `.nonactivatingPanel, .titled, .resizable, .closable, .fullSizeContentView`
- **Configuration:** `isFloatingPanel=true`, `level=.floating`, `collectionBehavior=[.canJoinAllSpaces, .fullScreenAuxiliary]`, hidden title, transparent titlebar
- **Key Overrides:** `canBecomeKey` and `canBecomeMain` both return `true` for interaction
- **State Preservation:** `setFrameAutosaveName("ClipFloatingPanel")` saves panel position/size
- **Minimal Buttons:** Traffic-light buttons hidden via `standardWindowButton()?.isHidden = true`

### Snippet.swift
- **Observable Model:** `@Observable final class Snippet: Identifiable, Codable` with UUID, name, content, category, isBuiltIn, creationDate
- **Init Pattern:** Name + content + optional category — creates new UUID and timestamp on init
- **SnippetStore Singleton:** `@Observable class SnippetStore` with static `.shared`, stores in `~/Library/Application Support/Clip/snippets.json`
- **Eager Persistence:** `snippets` property has `didSet { save() }` trigger — each mutation autosaves JSON
- **Load Strategy:** Constructor calls `load()` on init, seeds built-in templates if empty, catches errors silently
- **CRUD Methods:** `add()`, `delete()`, `duplicate()` — delete blocks built-in snippets via `guard !snippet.isBuiltIn`

### SnippetsView.swift
- **Tab Structure:** Toolbar with "Snippets" header + search, sections for "Templates" (built-in) and "My Snippets" (custom)
- **Search Filter:** `searchText` filters by name and content (case-insensitive), two-tier display with dividers
- **Sheet Editor:** `SnippetEditorView` modal for new/edit, passes selected snippet, mutates existing by direct property assignment then triggers save
- **Row Interaction:** Copy on tap, delete/edit on hover, context menu for copy/duplicate/delete
- **Empty State:** `ContentUnavailableView` with system image + descriptive text when no snippets

### ContentView.swift
- **Tab Selection:** `@State private var selectedTab = 0` — 4-tab segmented picker (Assets, Transform, Formatter, Snippets)
- **Environment Setup:** `@State private var snippetStore = SnippetStore.shared` + `.environment(snippetStore)` to child views
- **Pin Toggle Logic:** `isPinned` state, button cycles window `.level` between `.floating` and `.normal`
- **Theme Cycle:** `.system → .light → .dark → .system` via `@AppStorage("appTheme")`
- **Preview Router:** `previewRouter.pendingText` onChange listener switches to Transform tab (tab=1)
- **Header Draggable:** `WindowDragView()` in toolbar background makes panel movable by header

### HTMLPreviewView.swift
- **WKWebView Wrapper:** `NSViewRepresentable` with `makeNSView()` creating `WKWebView`, `updateNSView()` loading HTML string
- **HTML Template:** Embedded CSS with CSS variables for light/dark theme switching (`:root` + `@media (prefers-color-scheme: dark)`)
- **JS Callback Pattern:** No explicit JS bridge in this file — preview is static HTML render
- **Configuration:** `WKWebViewConfiguration()` default, `setValue(false, forKey: "drawsBackground")` for transparency
- **Footer Branding:** Hardcoded "MD Preview by Clip" footer appended to every rendered HTML

### RichTextTransformer.swift
- **Markdown to HTML:** `markdownToHTML(_ markdown: String) -> String` — line-by-line parser, handles headers, lists, tables, blockquotes, paragraphs
- **Signature:** Public static function, takes markdown string, returns HTML string
- **Table Rendering:** Dedicated `renderMarkdownTable()` detects separator row (`---|---`), splits header/body, generates `<table><thead><tbody>`
- **Inline Parsing:** `parseInline()` helper handles bold `**text**`, italic `*text*`, code `` `text` ``, links `[text](url)`
- **HTML to Markdown:** Reverse conversion via regex replacements, handles tables specially with `parseHTMLTable()`, fallback tag-stripping
- **No Dependencies:** Pure Foundation — no AppKit, no external libraries

### MarkdownPreviewRouter.swift
- **Observable Router:** `@Observable final class MarkdownPreviewRouter` singleton with `pendingText: String?`
- **Setter Pattern:** `request(_ text: String)` sets `pendingText`; `consume()` returns and clears in `defer` block
- **Usage in ContentView:** `onChange(of: previewRouter.pendingText)` listener triggers tab switch to Transform (index 1)
- **Cross-Tab Communication:** Allows Asset/Snippet views to queue markdown for Transform preview without direct coupling

### Package.swift
- **Target Structure:** Three executables (Clip app + CLI) + ClipCore library
- **Clip App Target:** Path `Sources`, excludes `ClipCore, ClipCLI, ClipQLPreview, ClipQLGenerator` subdirs
- **ClipCore Library:** Path `Sources/ClipCore`, contains pure-Foundation code (transformers, models)
- **Test Target:** `ClipTests` dependency on `Clip` (requires full Xcode for UI tests, per CLAUDE.md)
- **SPM Dependency:** Sparkle 2.6+ for auto-update, imported only in Clip executable (not ClipCore)

---

## Key Patterns for Notes Tab

| Pattern | Location | Usage |
|---------|----------|-------|
| **Observable Singleton Store** | `SnippetStore` | Auto-persist state to JSON, lazy-load on init |
| **Tab Index Selection** | `ContentView.selectedTab` | Index-based picker, switch case in body |
| **Environment Injection** | `ContentView.environment(snippetStore)` | Pass store to child views, access via `@Environment` |
| **Sheet Modal Editor** | `SnippetsView.sheet(isPresented:)` | Modal form with save/cancel callbacks |
| **Eager Auto-save** | `didSet { save() }` | Mutation triggers immediate JSON write |
| **Search + Filter** | `SnippetsView.filteredSnippets` | Computed property with lowercased contains check |
| **Cross-Tab Router** | `MarkdownPreviewRouter.request()` | Queue content for Transform preview, switch tabs via onChange |
| **Context Menu + Hover** | `SnippetRowView` | Dual interaction: tap to copy, hover for actions |

---

## Implementation Checklist for Notes Tab

**Data Layer:**
- [ ] Create `Note.swift` model (ID, title, content, category, createdDate, modifiedDate) with Codable
- [ ] Create `NoteStore` singleton with fileURL pattern, eager save, built-in seed templates

**UI Layer:**
- [ ] Create `NotesView.swift` (mirror `SnippetsView` structure: search, sections, rows)
- [ ] Create `NoteRowView.swift` with copy/delete/edit hover actions
- [ ] Create `NoteEditorView.swift` sheet modal (title + content textarea)

**Integration:**
- [ ] Add tab index 4 to `ContentView` segmented picker (icon: "doc.richtext")
- [ ] Add `@State private var noteStore = NoteStore.shared` to ContentView
- [ ] Inject `.environment(noteStore)` before NoteStore views render
- [ ] Update tab case in content switch statement

**Optional Enhancements:**
- [ ] Wire MarkdownPreviewRouter to Notes (allow request from NoteRowView)
- [ ] Add note categories filter dropdown (like "Templates" vs "My Snippets")
- [ ] Implement favorite/pin toggle for quick access

---

## Directory Structure for Notes Feature

```
Sources/
├── Models/
│   ├── Note.swift                 (new)
│   └── Snippet.swift              (reference)
├── Views/
│   ├── NotesView.swift            (new)
│   ├── NoteRowView.swift          (new)
│   ├── NoteEditorView.swift       (new)
│   └── SnippetsView.swift         (reference)
└── [existing views/AppDelegate/ContentView/etc.]
```

No changes to `ClipCore` library needed — Notes uses same `@Observable` pattern and JSON persistence as Snippets.

---

## Risk & Notes

- **File Size Concern:** FloatingPanel is 550x750px; ensure NoteEditor doesn't exceed sheet dimensions (current SnippetEditor is 480x420)
- **Performance:** Eager save on every `didSet` is acceptable for Notes unless > 1000 notes expected; consider debounce if scale needed
- **Accessibility:** Ensure sheet modals have proper focus/keyboard navigation (currently relies on default macOS behavior)
- **Built-in Templates:** Decide which note templates to seed (e.g., "Daily Notes", "Meeting Notes", "Retrospective")
