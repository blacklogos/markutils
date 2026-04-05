---
title: Open Source Readiness Audit — Swift macOS App
slug: open-source-readiness-swift-macos
category: best-practice
tags: [open-source, audit, swift, macos, nstextview, dead-code, gitignore]
problem_type: pre-publish checklist
component: whole repo
symptoms:
  - Personal email hardcoded in production code
  - Dead views and services not wired to any tab
  - Unused imports (SwiftData) inflating dependency surface
  - Empty function bodies with visible UI buttons
  - .gitignore missing local tool dirs (.claude/, .agent/, dmg_staging/)
  - .DS_Store files tracked in git
  - build_dmg.sh not executable
  - LICENSE and CHANGELOG incomplete
solved: true
date: 2026-04-06
---

## Problem

Before making a Swift macOS repo public, a full audit uncovered a mix of legal, security, dead-code, and hygiene issues spread across the codebase.

## Checklist

### Legal / identity
- [ ] LICENSE file present at repo root (MIT recommended for indie tools)
- [ ] No hardcoded personal email — replace `sendFeedback()` mailto links with a GitHub Issues URL

### Dead code
- [ ] All view files are reachable from `ContentView` tab routing
- [ ] All services are referenced by at least one live view
- [ ] No `import SwiftData` (or other framework imports) without actual usage

### Stub implementations
- [ ] Every function with a UI-visible button has a non-empty body
- [ ] Search for `{ }` or `{ return }` one-liners on public/visible methods

### Repo hygiene
- [ ] `.gitignore` covers: `.claude/`, `.agent/`, `dmg_staging/`, `*.dmg`, `build/`
- [ ] `git rm --cached` any `.DS_Store` files already tracked
- [ ] Shell scripts that must run are `chmod +x`

### Docs
- [ ] CHANGELOG has an entry for the release being published
- [ ] README install instructions match the actual build output

## Key fix: moveLine(direction:) — NSTextView line swap

Empty stub → full implementation using `NSString.lineRange(for:)`:

```swift
private func moveLine(direction: Int) {
    guard let editor else { return }
    let nsText = editor.string as NSString
    let cursorPos = editor.selectedRange().location
    guard cursorPos <= nsText.length else { return }

    let currentLineRange = nsText.lineRange(for: NSRange(location: cursorPos, length: 0))

    if direction < 0 {
        guard currentLineRange.location > 0 else { return }
        let prevLineRange = nsText.lineRange(for: NSRange(location: currentLineRange.location - 1, length: 0))
        let currentLine = nsText.substring(with: currentLineRange)
        let prevLine = nsText.substring(with: prevLineRange)
        let combinedRange = NSRange(location: prevLineRange.location,
                                    length: prevLineRange.length + currentLineRange.length)
        editor.insertText(currentLine + prevLine, replacementRange: combinedRange)
        editor.setSelectedRange(NSRange(location: prevLineRange.location, length: 0))
    } else {
        let nextStart = NSMaxRange(currentLineRange)
        guard nextStart < nsText.length else { return }
        let nextLineRange = nsText.lineRange(for: NSRange(location: nextStart, length: 0))
        let currentLine = nsText.substring(with: currentLineRange)
        let nextLine = nsText.substring(with: nextLineRange)
        let combinedRange = NSRange(location: currentLineRange.location,
                                    length: currentLineRange.length + nextLineRange.length)
        editor.insertText(nextLine + currentLine, replacementRange: combinedRange)
        editor.setSelectedRange(NSRange(location: currentLineRange.location + nextLineRange.length, length: 0))
    }
    text = editor.string
}
```

**Key API:** `NSString.lineRange(for:)` returns the full line including the trailing newline, so swapping two adjacent line ranges is safe without manual newline bookkeeping. Always sync `text = editor.string` after mutation so the SwiftUI binding stays in sync.

## Detection method

Run in sequence before any public release:

1. `grep -r "import " Sources/ | sort | uniq` — spot unused framework imports
2. Search for each view/service file name in `ContentView.swift` and any entry-point routing
3. `grep -rn "{ }" Sources/` — find empty function bodies
4. `grep -rn "@gmail\|@icloud\|@me.com" Sources/` — find personal contact info
5. `git ls-files | grep .DS_Store` — find tracked junk files
6. `ls -l scripts/` — verify execute bits on shell scripts
