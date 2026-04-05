# Clip

A lightweight macOS menu bar utility for content creators. Lives in the menu bar — no Dock icon, always one click away.

**Version 1.1.0** · macOS 14+ · Swift 5.9 · No dependencies

---

## What it does

Four tabs, each purpose-built:

### 🗂 Assets — The Vault
Drag images and text from anywhere into the vault. Organise into folders. Drag assets back out to Keynote, PowerPoint, Pages, or the Desktop. Everything persists across app launches (JSON, `~/Library/Application Support/Clip/`).

- Drag & drop import from Finder, browsers, or other apps
- Folder organisation with drag-to-nest
- Grid or compact list view
- Full-text search
- Right-click context menu (rename, delete, move)

### ⇄ Transform
Paste content — Clip auto-detects the type and offers the right actions.

| Detected type | Actions |
|---------------|---------|
| Markdown | Preview (rendered), Copy HTML, Copy Rich Text |
| Markdown table | To CSV, To TSV, Preview |
| TSV / Spreadsheet | To Markdown table, To CSV |
| CSV | To Markdown table, To TSV |
| HTML | To Markdown |
| Plain text | To Bullet List, To Numbered List |

Drag the rendered preview into any rich-text app (Apple Notes, Mail, Pages) to drop in formatted RTF.

### Aa Text Formatter
Two modes, toggled by the **Format / Convert** segmented picker:

**Format mode** — One toolbar row with primary actions and an overflow ⋯ menu:
- Unicode bold/italic character styling (𝐁 𝘐)
- Case transforms: ABC / Abc
- Bullet lists (•, ✅, 1.)
- Separator line
- Overflow: more bullet types, move line up/down, emoji inserts, number emojis, footer stamp

**Convert mode** — Social-media-ready Unicode output:
- **MD → Unicode** — converts full markdown document to Unicode-styled plain text
  (`**bold**` → 𝐛𝐨𝐥𝐝, `# H1` → 𝐁𝐎𝐋𝐃 HEADER, `` `code` `` → 𝚌𝚘𝚍𝚎, `- item` → • item, etc.)
- **Table → ASCII** — converts markdown tables to box-drawing tables (┌─┬─┐ style)
- Style buttons: apply bold / italic / bold-italic / monospace / script / small-caps / underline / strikethrough to selected text
- **Revert** — strips all Unicode styling back to plain ASCII

### 📄 Snippets
Store reusable text snippets with titles. Click to copy.

---

## Installation

### Option A — Download DMG (recommended)

1. Download **[Clip-1.1.0.dmg](https://github.com/blacklogos/markutils/releases/download/v1.1.0/Clip-1.1.0.dmg)**
2. Open the DMG and drag **Clip.app** to `/Applications`
3. Launch Clip from Spotlight or Finder

**Gatekeeper bypass (required — app is not notarized)**

macOS will block the app on first launch because it isn't signed with an Apple Developer certificate. Run this once after installation:

```bash
xattr -rd com.apple.quarantine /Applications/Clip.app
```

> **Tip:** If the command is denied, go to **System Settings → Privacy & Security → Full Disk Access** and enable your Terminal app, then run the command again.

After removing the quarantine flag, open **System Settings → Privacy & Security** and grant any permissions Clip requests (the app only needs standard window management — no screen recording or accessibility required).

Then double-click **Clip.app** to launch. The paperclip icon will appear in your menu bar.

---

### Option B — Build from source

```bash
git clone https://github.com/blacklogos/markutils.git
cd markutils
swift run
```

Requires Xcode Command Line Tools (`xcode-select --install`) or full Xcode.

To build your own DMG:

```bash
bash scripts/build_dmg.sh
```

---

## Interface

- **Menu bar icon**: left-click to show/hide the panel; right-click for the menu
- **Mouse shake**: shake the cursor vigorously to reveal the panel from any app
- **Pin button** (📌): keeps the window floating above other apps
- **Theme toggle** (☀️/🌙/⊙): cycles light → dark → system
- **Compressed header**: single-row with icon tabs, draggable gap in the middle
- **Status bar**: word count · char count · cursor line/col on text tabs

---

## Architecture

```
Sources/
├── AppDelegate.swift          # NSStatusItem, FloatingPanel lifecycle, mouse shake
├── ClipApp.swift              # @main, SwiftUI app entry
├── FloatingPanel.swift        # Custom NSPanel (non-activating, floating level)
├── Theme/
│   └── AppColors.swift        # Warm palette — dynamic light/dark via NSColor provider
├── Models/
│   ├── AssetStore.swift       # @Observable singleton, JSON persistence
│   └── Snippet.swift          # Codable snippet model
├── Services/
│   └── ClipboardMonitor.swift # NSPasteboard change monitoring
├── Utilities/
│   ├── RichTextTransformer.swift  # Markdown ↔ HTML ↔ NSAttributedString
│   ├── TableTransformer.swift     # TSV/CSV ↔ Markdown table
│   └── UnicodeTextFormatter.swift # Unicode style maps, MD→Unicode, table→ASCII box
└── Views/
    ├── ContentView.swift          # Root view, tab bar, theme
    ├── AssetGridView.swift        # Vault grid + search + drag/drop
    ├── QuickActionsView.swift     # Auto-detect transform tab
    ├── SocialMediaFormatterView.swift  # Text Formatter (Format + Convert modes)
    ├── SnippetsView.swift         # Snippets tab
    ├── HTMLPreviewView.swift      # WKWebView markdown preview (warm CSS)
    ├── StatusBarView.swift        # Word/char/cursor status bar
    └── ...                        # Supporting views
```

**Persistence:** Plain `Codable` + JSON, no SwiftData or Core Data.  
**Dependencies:** None. Pure Swift + AppKit + SwiftUI + WebKit.

---

## Build & Test

```bash
swift build          # compile
swift run            # run
swift test           # unit tests (requires full Xcode)
./scripts/verify_release.sh  # pre-release check
```

---

## For AI agents & contributors

Read [AGENT_RULES.md](AGENT_RULES.md) before making changes. Regression testing is mandatory — run `./scripts/verify_release.sh` before marking any task complete.
