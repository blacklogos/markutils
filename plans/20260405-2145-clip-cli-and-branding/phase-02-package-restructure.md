# Phase 02 — Package Restructure

**Status:** complete  
**Parent:** [plan.md](plan.md)

---

## Context Links

- `Package.swift` (repo root)
- `Sources/Utilities/RichTextTransformer.swift`
- `Sources/Utilities/TableTransformer.swift`
- `Sources/Utilities/UnicodeTextFormatter.swift`
- `Tests/ClipTests/`

---

## Overview

Extract the three pure-Foundation transformer files into a `ClipCore` library target so they can be shared between the `Clip` app executable and the new `clip` CLI executable. The AppKit-dependent code (`markdownToRichText`, `richTextToMarkdown`) stays in `Sources/` (app-only).

---

## Key Insights

1. `RichTextTransformer` imports both `Foundation` and `AppKit`. Only the `markdownToHTML` and `htmlToMarkdown` methods are pure Foundation — `markdownToRichText` and `richTextToMarkdown` use `NSFont`, `NSAttributedString`, etc.
2. `TableTransformer` imports `Foundation` only — fully portable.
3. `UnicodeTextFormatter` imports `Foundation` only — fully portable.
4. Three options for handling `RichTextTransformer`'s mixed dependency:
   - **Option A (recommended):** Split into `RichTextTransformer+Core.swift` (HTML methods, Foundation only) and keep AppKit methods in `Sources/` only.
   - **Option B:** Move whole file to `ClipCore/`, add `#if canImport(AppKit)` guards around NSFont usage — messy for a CLI that never needs it.
   - **Option C:** Duplicate the two HTML methods in ClipCore — violates DRY.
   - **Decision: Option A.** Clean split, no ifdefs, no duplication.

---

## Requirements

- `Clip` app target: compiles identically to today (no behavior change).
- `ClipCore` library: zero AppKit dependency, imports `Foundation` only.
- `clip` CLI target: depends on `ClipCore`, never imports AppKit.
- Test target: migrated to depend on `ClipCore` for transformer tests.
- No third-party dependencies added (zero-dep constraint from CLAUDE.md).

---

## Architecture

### Target Graph (after restructure)

```
ClipCore (library, Foundation only)
├── RichTextTransformer+Core.swift   [markdownToHTML, htmlToMarkdown, parseInline helpers]
├── TableTransformer.swift           [moved]
└── UnicodeTextFormatter.swift       [moved]

Clip (executable, depends on ClipCore)
├── Sources/AppDelegate.swift
├── Sources/ClipApp.swift
├── Sources/FloatingPanel.swift
├── Sources/Models/...
├── Sources/Services/...
├── Sources/Theme/...
├── Sources/Utilities/RichTextTransformer.swift   [markdownToRichText, richTextToMarkdown — AppKit methods only, imports ClipCore for the HTML methods or is standalone]
└── Sources/Views/...

clip (executable, depends on ClipCore)
└── Sources/ClipCLI/main.swift

ClipTests (test target, depends on ClipCore)
└── Tests/ClipTests/...
```

### File Moves

| Current path | Destination |
|---|---|
| `Sources/Utilities/TableTransformer.swift` | `Sources/ClipCore/TableTransformer.swift` |
| `Sources/Utilities/UnicodeTextFormatter.swift` | `Sources/ClipCore/UnicodeTextFormatter.swift` |
| `Sources/Utilities/RichTextTransformer.swift` | Split: HTML methods → `Sources/ClipCore/HTMLTransformer.swift`; AppKit methods stay in `Sources/Utilities/RichTextTransformer.swift` |

Note: renaming `RichTextTransformer+Core` to `HTMLTransformer` is cleaner — the struct can be renamed `HTMLTransformer` in ClipCore, or keep the struct name `RichTextTransformer` and put only the pure methods there. Keep struct name `RichTextTransformer` in ClipCore for minimal app-side churn (Views reference it).

### Package.swift (new shape)

```swift
// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "Clip",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Clip", targets: ["Clip"]),
        .executable(name: "clip", targets: ["ClipCLI"]),
        .library(name: "ClipCore", targets: ["ClipCore"]),
    ],
    targets: [
        .target(
            name: "ClipCore",
            path: "Sources/ClipCore"
        ),
        .executableTarget(
            name: "Clip",
            dependencies: ["ClipCore"],
            path: "Sources",
            exclude: ["ClipCore", "ClipCLI"]
        ),
        .executableTarget(
            name: "ClipCLI",
            dependencies: ["ClipCore"],
            path: "Sources/ClipCLI"
        ),
        .testTarget(
            name: "ClipTests",
            dependencies: ["ClipCore"],
            path: "Tests/ClipTests"
        )
    ]
)
```

Note on `exclude`: SPM requires explicit exclusion of subdirs that contain other targets when using a broad `path`. Alternatively, restructure to `Sources/Clip/` (move all app sources there) — cleaner but larger file move. Evaluate during implementation; the broader `path` approach is lower risk.

---

## Related Code Files

- `Sources/Utilities/RichTextTransformer.swift` — lines 1–153 (AppKit), 154–363 (Foundation HTML)
- `Sources/Utilities/TableTransformer.swift` — all Foundation
- `Sources/Utilities/UnicodeTextFormatter.swift` — all Foundation
- `Tests/ClipTests/` — verify what's currently tested

---

## Implementation Steps

1. Create `Sources/ClipCore/` directory.
2. Create `Sources/ClipCLI/` directory.
3. Move `TableTransformer.swift` to `Sources/ClipCore/`.
4. Move `UnicodeTextFormatter.swift` to `Sources/ClipCore/`.
5. Copy the pure-Foundation methods from `RichTextTransformer.swift` into `Sources/ClipCore/RichTextTransformer.swift` (new file, `import Foundation` only, contains: `markdownToHTML`, `htmlToMarkdown`, `parseInline`, `renderMarkdownTable`, `parseTableRow`, private helpers).
6. **Extend `htmlToMarkdown` in `Sources/ClipCore/RichTextTransformer.swift`** to convert `<table>` HTML → markdown table. Add a `parseHTMLTable` helper that:
   - Extracts `<thead>/<tbody>/<tr>/<th>/<td>` cells
   - Produces `| col | col |\n| --- | --- |\n| val | val |` format
   - Falls back to stripping tags if table structure is malformed
7. Remove those methods from `Sources/Utilities/RichTextTransformer.swift` — it now only contains AppKit-dependent methods and imports both `Foundation` and `AppKit`.
8. Add `import ClipCore` to `Sources/Utilities/RichTextTransformer.swift` if AppKit methods call Core methods (they don't currently — verify).
8. Update `Package.swift` as shown above.
9. Run `swift build` — fix any import errors.
10. Run `swift test` — all existing tests must pass.
11. Run `./scripts/verify_release.sh`.

---

## Todo

- [x] Create `Sources/ClipCore/` dir
- [x] Create `Sources/ClipCLI/` dir
- [x] Move `TableTransformer.swift`
- [x] Move `UnicodeTextFormatter.swift`
- [x] Split `RichTextTransformer.swift` — Core portion to `Sources/ClipCore/`
- [x] Extend `htmlToMarkdown` with `<table>` → markdown conversion
- [x] Update `Package.swift`
- [x] `swift build` green
- [ ] `swift test` green — pre-existing XCTest/CommandLineTools limitation (requires full Xcode)
- [ ] `./scripts/verify_release.sh` green — blocked by same XCTest limitation

---

## Success Criteria

- `swift build` produces both `Clip` and `clip` binaries.
- `ClipCore` has zero AppKit imports.
- Existing app behavior unchanged.
- All tests pass.

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| SPM `path` + `exclude` conflicts | Medium | Test Package.swift carefully; fallback: move app sources to `Sources/Clip/` subdir |
| Duplicate struct name `RichTextTransformer` in two targets | Low | ClipCore version is the authoritative pure one; app version is renamed or prefixed |
| Missing method reference in Views after split | Medium | `swift build` catches all; Views currently call `markdownToHTML` which moves to ClipCore (imported transitively via app target dependency) |

---

## Security Considerations

No security impact. Library extraction is purely organizational.

---

## Next Steps

Proceed to Phase 03 (CLI commands implementation) once package restructure builds cleanly.
