---
module: Clip Notes
date: 2026-04-26
problem_type: ui_bug
component: frontend_stimulus
symptoms:
  - "Clicking empty space in note row does nothing; must click exactly on text"
  - "Full-row tap target missing in SwiftUI LazyVStack / List rows"
root_cause: wrong_api
resolution_type: code_fix
severity: medium
tags: [swiftui, hit-testing, contentshape, clear-background, button, row-selection]
---

# SwiftUI: Color.clear Background Has No Hit Area

## Symptom

Note rows in a sidebar `LazyVStack` required clicking exactly on the `Text` labels
to trigger selection. Clicking any empty padding area of the row did nothing.

## Environment

- macOS 14+, Swift 5.9, SwiftUI
- Files: `Sources/Views/NotesView.swift` (NoteRowView), `Sources/Views/MinimalNotesView.swift` (searchRow)

## Root Cause

SwiftUI hit-testing only covers pixels with a **non-clear rendered content**. When a
`Button` label's background is `Color.clear` (the default for unselected rows), the
transparent area is invisible to the hit-tester — only the actual `Text` glyphs respond
to taps.

## Failed Approaches

- Wrapping `VStack` in an extra `HStack(spacing: 0)` — no effect on hit area.
- Setting `.frame(maxWidth: .infinity)` alone — extends the frame but not the hit area.

## Solution

Add `.contentShape(Rectangle())` **after** `.background()` on the button's label view.
This explicitly declares the entire rectangle as the tappable region regardless of
background color.

```swift
// BEFORE — only text pixels are tappable
Button(action: onTap) {
    VStack(alignment: .leading, spacing: 2) { ... }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? AppColors.accent.opacity(0.12) : Color.clear)
}
.buttonStyle(.plain)

// AFTER — full row area is tappable
Button(action: onTap) {
    VStack(alignment: .leading, spacing: 2) { ... }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? AppColors.accent.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())   // ← fixes hit area
}
.buttonStyle(.plain)
```

## Prevention

**Rule:** Any `Button` or tap gesture whose label uses `Color.clear` (or any other
transparent/invisible fill) **must** have `.contentShape(Rectangle())` on the label
root view, placed after `.background()`.

Applies to:
- Sidebar row views
- List rows with conditional backgrounds
- Any gesture receiver over a transparent area

## Related

- Apple docs: [`contentShape(_:eoFill:)`](https://developer.apple.com/documentation/swiftui/view/contentshape(_:eofill:))
- Same fix applied in two places: `NoteRowView` and `MinimalNotesView.searchRow`
