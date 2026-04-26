# Changelog

All notable changes to Clip are documented here.

---

## v1.5.0 — 2026-04-26

### New features

**Notes Tab** (#15)
- Daily markdown editor built into the main window (tab 4)
- Auto-creates a "today" note on first open
- Inline markdown styling (bold, italic, strikethrough, code, headings, blockquotes)
- Keyword expansion: `::meeting`, `::proposal`, `::slides`, `::table`, `::today`, `::tomorrow`, `[ ]`
- Preview rendered markdown with interactive checkboxes
- Send note to Transform tab, copy to clipboard, export as `.md`
- Floating Notes panel (⌥A) for distraction-free writing alongside any app

**Compact Icon Titlebar**
- Replaced segmented tab picker with compact SF Symbol icon buttons inline with traffic lights
- Each icon has a hover tooltip (Assets, Transform, Text Formatter, Notes)
- Theme cycle and pin-to-top controls in the same row
- Eliminated rogue `WindowGroup` window that was causing the tab bar to render invisible on first launch

**Quick Look Extension**
- `.clip` vault files preview in Finder via Quick Look
- CLI quarantine fix bundled

**Bundled CLI**
- `clip` command-line tool bundled inside the app
- Prompts to install on first launch; also available via menu bar → Install CLI…

### Bug fixes

- Fixed `WindowGroup` creating a second standard window on launch — tab icons were rendering behind the native titlebar material and appearing invisible
- Fixed paste-as-PNG producing empty files
- Fixed Markdown preview routing between tabs
- Fixed `@rpath` for `Sparkle.framework` so the app launches correctly when built with SPM
- Fixed `ClipQLGenerator` excluded from SPM target (requires Developer ID to build)

---

## v1.4.0 — 2026-04-09

### New features

**Recursive Vault Search** (#6)
- Search now descends into nested folders at any depth
- Matching assets are flattened into the results while preserving sections
- 10 unit tests for search logic

**Markdown File Preview & Import** (#8, #9)
- `Asset.fileFormat` field tracks the original file extension (backward-compatible with v1.3 vaults)
- MD badge overlay on markdown text assets
- "Preview Rendered" context menu action on markdown assets — opens Transform tab with live preview
- "Open File…" button in Transform tab loads `.md` files via NSOpenPanel
- `MarkdownPreviewRouter` singleton routes markdown content from vault to Transform tab

**SVG Copy & PNG Paste** (#7)
- "Copy as SVG" for text assets containing SVG markup (registers `public.svg-image`)
- SVG drag-out via NSItemProvider for design tool interop
- "Paste PNG" toolbar button converts any clipboard image to PNG asset
- Error alert when clipboard is empty or non-image

**Sparkle Auto-Update** (#5)
- Replaced custom `UpdateChecker.swift` with Sparkle framework (de-facto macOS auto-update)
- `SPUStandardUpdaterController` wired in AppDelegate — auto-checks on launch
- "Check for Updates…" menu item targets Sparkle directly
- `build_dmg.sh` bundles `Sparkle.framework` in `Contents/Frameworks/`
- `appcast.xml` with EdDSA-signed release entry
- `CFBundleIdentifier` fixed from `com.example.Clip` to `io.blacklogos.clip`

### Changes
- Version bumped to 1.4.0, build number 5
- `*.pem` added to `.gitignore`
- `Package.resolved` committed for reproducible builds

---

## v1.3.0 — 2026-04-08

### New features

**App Icon**
- Custom paperclip mascot icon — replaces the generic macOS app icon in Finder, Dock (when visible), and About dialogs

**Split View for Transform tab** (#2)
- Toggle button switches between stacked (vertical) and side-by-side (horizontal) layout
- Compare input and output content side by side for easier review

**Auto-Update** (#3)
- Checks GitHub Releases on launch for newer versions (silent — only shows an alert when an update is found)
- "Check for Updates…" menu item for manual checks
- One-click download of the latest DMG from the update alert

**Export/Import Vault** (#4)
- **GUI**: "Export Vault…" / "Import Vault…" menu items with native file dialogs
- **CLI**: `clip export` and `clip import` subcommands
  - Supports stdin/stdout piping and `--file` flag
  - Validates JSON before importing; vault unchanged on invalid input
- Pretty-printed JSON output for human-readable backups
- Import replaces the full vault (with confirmation dialog in GUI)

### Changes
- `build_dmg.sh` now copies `AppIcon.icns` into the app bundle and sets `CFBundleIconFile` in Info.plist
- CLI help updated with export/import subcommand documentation
- Version bumped to 1.3.0

---

## v1.2.1 — 2026-04-07

### Bug fixes

- **Fixed DMG producing a broken Clip.app** — the `Clip` (app) and `clip` (CLI) product names collided on macOS's case-insensitive filesystem, causing the CLI binary to overwrite the app binary. Renamed CLI product to `clip-tool` in Package.swift; end-user `clip` command name is unchanged.
- Removed dead `AIService` test stubs that referenced an unimplemented class, fixing `swift test` failures.

### Changes
- Updated `build_dmg.sh`, `install_cli.sh`, README, and docs to reflect the `clip-tool` product rename.

---

## v1.2.0 — 2026-04-06

### New features

**`clip` CLI companion**
- New `clip` command-line binary: `md2html`, `html2md`, `md2social` subcommands
- Reads from stdin by default; `--clipboard` / `-c` flag transforms clipboard in-place (no pipes needed)
- Bundled in the DMG alongside the app — double-click "Install CLI.command" to install

**Package restructure**
- `ClipCore` library extracted: pure-Foundation transformers (`RichTextTransformer` HTML methods, `TableTransformer`, `UnicodeTextFormatter`) shared between app and CLI
- `AppKit` extension on `RichTextTransformer` remains in the app target only

### Changes
- "Send Feedback" menu item now opens GitHub Issues instead of email
- Removed unused `AIView` and stub `AIService` (AI slide generation was not wired up)
- Implemented Move Line Up/Down in Text Formatter overflow menu
- `build_dmg.sh` now builds both `Clip` and `clip` binaries and stages full DMG with install script

---

## v1.1.0 — 2026-04-05

**[Download Clip-1.1.0.dmg](https://github.com/blacklogos/markutils/releases/download/v1.1.0/Clip-1.1.0.dmg)**

> Not notarized. Remove quarantine after install: `xattr -rd com.apple.quarantine /Applications/Clip.app`

### New features

**Unicode Text Formatter (Convert mode)**
- New **Format / Convert** segmented picker in the Text Formatter tab
- **MD → Unicode**: converts full markdown to Unicode-styled plain text — bold, italic, monospace, strikethrough, bullet points, headers, blockquotes, horizontal rules, links, and embedded tables
- **Table → ASCII**: converts markdown tables to box-drawing tables (┌─┬─┐/╞═╪═╡ style)
- 8 style buttons apply Unicode styling to selections: 𝐁old, 𝘐talic, 𝒃𝒊 Bold Italic, 𝚖onospace, 𝒮cript, ꜱᴄ Small Caps, u̲nderline, s̶trikethrough
- **Revert** button strips all Unicode styling back to plain ASCII
- `Sources/Utilities/UnicodeTextFormatter.swift` — standalone utility with no dependencies

**Warm Minimal UI**
- Compressed header: two rows (title + tabs) → single 40px row
- Icon-only tabs with `.help()` tooltips for discoverability
- Theme cycle button — cycles System ⊙ → Light ☀️ → Dark 🌙
- Status bar on Transform and Text Formatter tabs: word count · char count · Ln/Col
- Centralized warm color palette (`AppColors`) responding to light/dark mode changes dynamically

**Text Formatter toolbar collapse**
- Format mode: 3 rows of buttons → 1 compact row
- Overflow **⋯** menu: extra bullet types, move line up/down, fix spaces, emoji inserts, number emojis, footer
- Removed redundant Undo/Redo buttons (Cmd+Z/Shift+Z work natively)
- Copy button now uses amber accent color

### Changes

- `HTMLPreviewView`: body font changed to Georgia serif; headers remain sans-serif; all colors via CSS custom properties with warm light/dark variants; blockquote border uses amber accent
- `AssetGridView`, `QuickActionsView`: warm background colors applied
- `ContentView`: header rebuilt from scratch as single `HStack`; draggable gap between tabs and controls
- `AppColors.swift` (new): centralized palette using `NSColor(name:dynamicProvider:)` for correct light/dark transitions without needing `@Environment` at call sites
- `StatusBarView.swift` (new): reusable 22px bar with word count, char count, Ln/Col
- `docs/solutions/` (new): solution documentation for Unicode scalar arithmetic pattern and NSColor dynamic provider pattern

### Bug fixes

- Fixed type-checker timeout in `NSColor` hex initializer (broke arithmetic into separate `let` bindings)
- Fixed `sRGBRed:` → `srgbRed:` label mismatch (AppKit API)

---

## v1.0.0 — 2025-11-23

Initial public release.

### Features

- Menu bar paperclip icon, floating panel, mouse-shake gesture to reveal
- Asset Vault: drag & drop images and text, folder organisation, grid/compact views, full-text search, drag-out export
- Transform tab: auto-detect content type (Markdown, Markdown table, TSV, CSV, HTML, plain text) with contextual action bar and rendered HTML preview with RTF drag-out
- Text Formatter: Unicode bold/italic, case transforms, bullet/numbered lists, emoji toolbar, footer stamp, number emoji row
- Snippets tab: store and copy reusable text snippets
- Persistent JSON storage in `~/Library/Application Support/Clip/`
- No Dock icon (accessory mode), single-instance enforcement
