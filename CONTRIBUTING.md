# Contributing to Clip

Thanks for your interest in contributing! Clip is a macOS menu bar utility for content creators — an asset vault, Markdown transformer, Unicode text formatter, and daily notes editor, all in one panel.

## Development Setup

### Prerequisites

- **Xcode 15+** (full app, not just Command Line Tools — required for `swift test`)
- macOS 14+
- Swift 5.9

### Clone and Build

```bash
git clone https://github.com/blacklogos/markutils.git
cd markutils
swift build
swift run          # build + launch the app
```

### Run Tests

```bash
./scripts/verify_release.sh   # build + full test suite (mandatory before any PR)
swift test                    # tests only
```

> **Note:** `swift test` requires the full Xcode app. With Command Line Tools only, XCTest is unavailable and tests will fail with "no such module 'XCTest'".

## Making Changes

### 1. Create a Branch

```bash
git checkout main && git pull
git checkout -b feat/your-feature     # or: fix/bug-description, docs/section-name
```

### 2. Code Style

No linter or formatter is configured. Follow the patterns in the code you're changing:

- SwiftUI views in `Sources/Views/`
- AppKit integration in `Sources/` root (`AppDelegate`, `FloatingPanel`, `NotesPanel`)
- Pure-logic utilities in `Sources/ClipCore/` (no AppKit dependency — shared with CLI)
- Models in `Sources/Models/`

Keep functions short, names obvious, and avoid clever tricks. If you need to explain it, simplify it.

### 3. Commit Messages

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(notes): add keyword expansion for ::standup template
fix(transform): correct RTF drag encoding for special characters
docs: update architecture section in CONTRIBUTING.md
chore: bump Sparkle to 2.7.0
release: v1.6.0 — summary line
```

Scopes are optional but helpful (e.g. `assets`, `transform`, `notes`, `cli`, `ui`).

### 4. Tests

Tests live in `Tests/ClipTests/`. Add tests for any new logic in `ClipCore` or `Models`. UI-layer code (`Views/`) is not unit-testable without a full Xcode run target — cover the logic, not the SwiftUI body.

```bash
./scripts/verify_release.sh   # must pass before opening a PR
```

### 5. Submit a Pull Request

```bash
git push origin feat/your-feature
gh pr create --title "feat: Description" --body "Closes #N"
```

**PR checklist:**

- [ ] `./scripts/verify_release.sh` passes
- [ ] Commit messages follow the conventional format
- [ ] One logical change per PR
- [ ] No new dependencies without prior discussion

## Project Architecture

```
Sources/
├── ClipApp.swift                  # @main — Settings scene only (no WindowGroup)
├── AppDelegate.swift              # NSStatusItem, FloatingPanel, MouseShakeDetector
├── FloatingPanel.swift            # NSPanel subclass — stays on top, hides dock icon
├── NotesPanel.swift               # Floating notes window (⌥A)
│
├── ClipCore/                      # Pure-Foundation library — shared with CLI
│   ├── RichTextTransformer.swift  # Markdown ↔ HTML ↔ NSAttributedString
│   ├── TableTransformer.swift     # TSV/CSV ↔ Markdown tables
│   └── UnicodeTextFormatter.swift # MD → Unicode styled text
│
├── ClipCLI/
│   └── main.swift                 # clip binary: md2html, html2md, md2social, export, import
│
├── Models/
│   ├── Asset.swift                # Codable asset tree (text, image, folder)
│   ├── AssetStore.swift           # @Observable singleton, JSON persistence
│   ├── Note.swift                 # Daily notes model
│   ├── Snippet.swift              # Reusable text snippets
│   └── MarkdownPreviewRouter.swift# Routes vault MD assets to Transform tab
│
├── Views/
│   ├── ContentView.swift          # Root: compact titlebar + tab switcher
│   ├── AssetGridView.swift        # Tab 0 — drag-and-drop vault
│   ├── QuickActionsView.swift     # Tab 1 — Markdown/HTML/table transformer
│   ├── SocialMediaFormatterView.swift  # Tab 2 — Unicode text formatter
│   └── NotesView.swift            # Tab 3 — daily markdown editor
│
└── Theme/
    └── AppColors.swift            # Centralized warm amber palette (light/dark)

Tests/ClipTests/                   # XCTest logic tests (requires full Xcode)
scripts/
├── verify_release.sh              # Mandatory pre-release gate: build + test
├── build_dmg.sh                   # Builds and signs the DMG for distribution
└── install_cli.sh                 # Installs clip binary to /usr/local/bin
```

**Data flow:** `AssetStore` (singleton) → `AssetGridView`. Transform tab uses `RichTextTransformer` + `TableTransformer` from `ClipCore`. Notes tab persists to `~/Library/Application Support/Clip/notes/`. The CLI (`ClipCLI`) links only against `ClipCore` — no AppKit.

## What We're Looking For

- Bug fixes with a reproduction case and/or test
- Documentation improvements
- Performance improvements with a measurable benchmark
- New features — please open an issue first to discuss scope

## What We're NOT Looking For

- Style-only changes without functional improvement
- New dependencies without prior discussion
- Features that require network access or cloud storage
- Anything that adds a Dock icon or changes the accessory-app behavior

## Need Help?

- Open an [issue](https://github.com/blacklogos/markutils/issues)
- Read [CLAUDE.md](CLAUDE.md) for the full architecture and constraint summary
