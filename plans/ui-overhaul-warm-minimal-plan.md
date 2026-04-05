# UI Overhaul: Warm Minimal Design

## Design Direction
Inspired by mx editor — warm tones, minimal chrome, content-first. Not a copy — applying the philosophy to Clip's multi-tool nature.

## Color System

### Accent: Warm Amber `#C47D4E`

### Light Theme
| Element | Color |
|---------|-------|
| Window bg | `#FAF8F5` |
| Editor bg | `#F7F4EF` |
| Toolbar bg | `#F0EDE8` |
| Text primary | `#2C2C2C` |
| Text secondary | `#8A8078` |
| Divider | `rgba(160,140,120,0.15)` |
| Accent | `#C47D4E` |
| Active tab bg | `#E8E2DA` |

### Dark Theme
| Element | Color |
|---------|-------|
| Window bg | `#1E1E1E` |
| Editor bg | `#252525` |
| Toolbar bg | `#2A2A2A` |
| Text primary | `#E8E0D8` |
| Text secondary | `#8A8078` |
| Divider | `rgba(160,140,120,0.12)` |
| Accent | `#D4956A` |
| Active tab bg | `#3A3530` |

### System Theme
Keep current macOS defaults as fallback option.

---

## Layout Changes

### 1. Header Compression (80px → ~40px)

**Before:**
```
┌────────────────────────────────────────────┐
│  [space]        📎 Clip        [pin]       │  ← row 1 (title)
│  [Assets] [Transform] [Formatter] [AI]     │  ← row 2 (tabs)
├────────────────────────────────────────────┤
```

**After:**
```
┌────────────────────────────────────────────┐
│  [🗂] [⇄] [Aa]          🌙  📌            │  ← single row
├────────────────────────────────────────────┤
```

- Remove "Clip" title text — paperclip icon stays as app identity in menu bar
- Tab icons only, no text labels:
  - `square.grid.2x2` = Assets
  - `arrow.left.arrow.right` = Transform  
  - `textformat.abc` = Text Formatter
- `.help()` tooltips on each icon for discoverability
- Remove AI tab entirely (not needed per user)
- Pin + theme toggle right-aligned
- Gap between icons and right controls = draggable area

**File**: `Sources/Views/ContentView.swift`

### 2. Status Bar (text-editing tabs only)

```
│  419 words  •  2,502 chars  •  Ln 12, Col 4  │  ← 20px
```

- Show on Transform and Text Formatter tabs
- Hide on Assets tab
- Read from `editor.string` for word/char count
- Read from `editor.selectedRange()` for Ln/Col
- Update on `textDidChange` delegate callback

**Files**: `Sources/Views/TransformerView.swift`, `Sources/Views/SocialMediaFormatterView.swift`

New shared component: `Sources/Views/StatusBarView.swift`

```swift
struct StatusBarView: View {
    let text: String
    let cursorPosition: NSRange?
    // Computes word count, char count, line/col from text + cursor
}
```

### 3. Transform Tab — Single Toolbar Row

**Before:** 2 segmented pickers (transform type + view mode) stacked vertically

**After:**
```
┌────────────────────────────────────────────┐
│  [MD↔HTML] [Table]  │  [👁]  │  [📋]       │
├────────────────────┬───────────────────────┤
│  (editor)          │  (preview)            │
├────────────────────┴───────────────────────┤
│  312 words  •  1,847 chars                 │
└────────────────────────────────────────────┘
```

- Transform type: small segmented, left
- Eye icon: cycles edit → split → preview (single button, not picker)
- Copy icon: right-aligned
- Remove the separate "Markdown Input" / "Preview" sub-headers — the layout makes it obvious

**File**: `Sources/Views/TransformerView.swift`

### 4. Text Formatter — Collapse Toolbar

**Before:** 3 rows of buttons (undo/redo + styles, lists + move + emojis, numbers + footer + copy)

**After:** 1 icon row + overflow menu
```
┌────────────────────────────────────────────┐
│ [𝐁] [𝘐] [ABC] [Abc] [•] [✅] [1.] [──] [📋] [⋯] │
└────────────────────────────────────────────┘
```

- Primary actions: bold, italic, uppercase, capitalize, bullet, checkmark bullet, numbered list, separator, copy
- Overflow menu `⋯`: remaining bullets (🔸⭐️🔹-), move up/down, fix spaces, emoji inserts (💡🚀✨❤️👉), number emojis, footer
- Remove undo/redo buttons — `Cmd+Z` / `Cmd+Shift+Z` already work natively via NSTextView

**File**: `Sources/Views/SocialMediaFormatterView.swift`

### 5. HTMLPreviewView CSS — Warm Typography

Update the CSS in `HTMLPreviewView.swift`:
- Body font: system serif (Georgia, "Times New Roman", serif)
- Headers: keep sans-serif (-apple-system) for contrast
- Warm background: match editor bg colors from theme
- Link color: accent amber instead of blue

**File**: `Sources/Views/HTMLPreviewView.swift`

### 6. Window Unlocking

- `ClipApp.swift`: Remove `.fixedSize()` and `.windowResizability(.contentSize)`
- `FloatingPanel.swift`: Add `self.minSize = NSSize(width: 400, height: 350)` and `self.setFrameAutosaveName("ClipPanel")`

---

## New File: `Sources/Theme/AppColors.swift`

Centralized color definitions. All views reference this instead of hardcoded `NSColor` system colors.

```swift
struct AppColors {
    // Detects system appearance, returns warm light or warm dark palette
    static var windowBackground: Color { ... }
    static var editorBackground: Color { ... }
    static var toolbarBackground: Color { ... }
    static var textPrimary: Color { ... }
    static var textSecondary: Color { ... }
    static var accent: Color { ... }
    static var divider: Color { ... }
    static var activeTab: Color { ... }
}
```

Uses `@Environment(\.colorScheme)` at call site or `NSApp.effectiveAppearance` for static contexts.

---

## File Changes Summary

| File | Action | Changes |
|------|--------|---------|
| `Sources/Theme/AppColors.swift` | NEW | Centralized warm color palette |
| `Sources/Views/StatusBarView.swift` | NEW | Shared word/char/cursor status bar |
| `Sources/Views/ContentView.swift` | MODIFY | Compress header, icon tabs, remove AI tab, apply warm colors |
| `Sources/Views/TransformerView.swift` | MODIFY | Single toolbar row, eye toggle, status bar, warm colors |
| `Sources/Views/SocialMediaFormatterView.swift` | MODIFY | Collapse 3 rows → 1 + overflow, status bar, warm colors |
| `Sources/Views/AssetGridView.swift` | MODIFY | Apply warm background colors |
| `Sources/Views/HTMLPreviewView.swift` | MODIFY | Warm CSS, serif body font |
| `Sources/ClipApp.swift` | MODIFY | Remove fixed size constraints |
| `Sources/FloatingPanel.swift` | MODIFY | Add minSize + frame autosave |

## Risks
- **Warm colors on non-calibrated displays**: amber accent may look muddy. Mitigate by keeping saturation moderate.
- **Icon-only tabs**: first-time users may not know what icons mean. `.help()` tooltips + onboarding update mitigate this.
- **Toolbar collapse**: power users may miss quick access to niche buttons. Overflow menu preserves access.
