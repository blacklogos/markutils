# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Clip is a macOS menu bar utility for content creators. It runs as an accessory app (no Dock icon) with a floating panel accessed via the menu bar paperclip icon or mouse-shake gesture. Built with Swift 5.9, SwiftUI + AppKit hybrid, targeting macOS 14+.

## Build & Run Commands

```bash
swift build          # Build the project
swift run            # Build and run
swift test           # Run unit tests (requires full Xcode, not just CommandLineTools)
./scripts/verify_release.sh   # Mandatory before marking any task complete — builds + tests
```

There is no linter or formatter configured. No third-party dependencies.

## Architecture

**App lifecycle:** `ClipApp` → `AppDelegate` manages the `NSStatusItem` (menu bar icon), a `FloatingPanel` (custom `NSPanel` subclass that stays on top), and a `MouseShakeDetector` for shake-to-reveal. The app enforces single-instance via bundle ID check at launch.

**Data layer:** `AssetStore` is a singleton `@Observable` class that persists `[Asset]` as JSON to `~/Library/Application Support/Clip/assets.json`. Assets can be text, image, or folder (recursive tree via `children`). No SwiftData despite what docs say — it's plain Codable + JSON file I/O.

**Tabs in ContentView** (index-based `selectedTab`, ⌘1–⌘6 shortcuts):
- 0: `AssetGridView` — drag-and-drop vault for images/text with folder organization
- 1: `MarkdownReaderView` — view .md files/folders (sidebar tree, live reload, Finder "Open With" via `application(_:open:)`); state in `MarkdownDocumentStore`
- 2: `QuickActionsView` — auto-detecting transform: markdown ↔ HTML (WebKit live preview), tables ↔ CSV/TSV
- 3: `SocialMediaFormatterView` — Unicode text styling for social media (Vietnamese accent/natural modes)
- 4: `NotesView` — daily notes (also reachable via ⌥A floating panel)
- 5: `DiffView` — paste two texts, side-by-side diff with precision picker (smart/line/word/char); engine in ClipCore `TextDiff*`

**Transformer pipeline:** `RichTextTransformer` handles markdown ↔ HTML and markdown ↔ NSAttributedString conversions. `TableTransformer` handles TSV/CSV ↔ markdown table. The preview pane uses `HTMLPreviewView` (WKWebView) rendering HTML output from `RichTextTransformer.markdownToHTML()`.

**Window management:** `FloatingPanel` is a non-activating `NSPanel` with `.floating` level. Close button hides instead of quitting (`windowShouldClose` returns false). Pin toggle switches between `.floating` and `.normal` window level.

## Key Constraints

- **No XCTest UI testing** — only logic/unit tests work with CommandLineTools SDK. Tests live in `Tests/ClipTests/`.
- **Accessory app** — `NSApp.setActivationPolicy(.accessory)` means no Dock icon. The status item menu only appears on right-click; left-click toggles the panel.
- **Asset persistence** is eager — `AssetStore.assets.didSet` triggers save on every mutation.
- Regression testing is mandatory per `AGENT_RULES.md`. Run `./scripts/verify_release.sh` before completing work.
