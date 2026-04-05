# Changelog

All notable changes to Clip are documented here.

---

## v1.1.0 — 2026-04-05

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
