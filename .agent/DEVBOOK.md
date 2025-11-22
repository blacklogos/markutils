# Dev Book: Clip App

_A compounding knowledge base. Every mistake teaches. Every pattern strengthens._

---

## Core Principles

1. **Mistakes are investments** - Document them, learn from them, never repeat them
2. **Patterns compound** - Recognize what works, codify it, reuse it
3. **Context is king** - Future you (or future AI) needs to understand _why_
4. **Simple beats clever** - The best solution is the one you can explain in one sentence

---

## Mistakes & Lessons

### UI Sizing

**Mistake:** Added UI elements without resizing container → cropped display

**Made:** 3 times (Session 4, Session 6, Session 6 Post-Journal)

**Lesson:** When adding UI elements (especially in a fixed-size window), ALWAYS:

1. Count the vertical/horizontal space needed
2. Update window dimensions in `AppDelegate.swift` → `FloatingPanel` init
3. Test with actual content, not empty state

**Rule:** `New UI Element = Check Container Size`

---

### Force Unwrapping Optionals

**Mistake:** `modelContainer!` crashed when SwiftData failed to initialize

**Made:** 1 time (Session 2)

**Lesson:** Never force unwrap in production code. Use:

```swift
if let container = modelContainer {
    // Safe path
} else {
    // Fallback path
}
```

**Rule:** `Force Unwrap = Potential Crash`

---

### SwiftUI MenuBarExtra Limitations

**Mistake:** Used `MenuBarExtra` for interactive content → window dismissed on click

**Made:** 1 time (Session 6)

**Lesson:** `MenuBarExtra` is for menus, not working apps. For persistent floating windows:

- Use `NSStatusItem` + custom `NSPanel`
- Set `.level = .floating`
- Control dismiss behavior explicitly

**Rule:** `Interactive UI = NSPanel, Not MenuBarExtra`

---

### Drag-and-Drop Conflicts

**Mistake:** `.draggable()` on images conflicted with window drag

**Made:** 1 time (Session 6)

**Lesson:** Separate drag zones:

- Header area: `WindowDragView` for window movement
- Content area: `.onDrag` for item dragging
- Set `isMovableByWindowBackground = false` on NSPanel

**Rule:** `One Element = One Drag Purpose`

---

## Patterns That Work

### Living Documentation

**Pattern:** Keeping PRD and documentation in sync with code changes immediately.

**Why:** Prevents "documentation drift" where docs become obsolete. Serves as a reliable source of truth for future agents.

---

### Menu Bar App Architecture

```swift
// AppDelegate pattern for menu bar apps
class AppDelegate: NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var floatingPanel: FloatingPanel!

    func applicationDidFinishLaunching() {
        NSApp.setActivationPolicy(.accessory) // Hide dock icon
        // Setup status item + panel
    }
}
```

**Why:** Full control over lifecycle and window behavior

---

### Smart Content Detection

```swift
// Auto-detect content type and suggest transformation
func detectContentType(_ text: String) {
    if text.contains("|") && text.contains("---") {
        selectedTransform = .markdownToTSV
        smartDetected = true // Show ⚡ indicator
    }
}
```

**Why:** Reduces cognitive load. App understands intent.

---

### Bidirectional Transformations

```swift
// Always provide reverse transformation
enum TransformType {
    case markdownToTSV
    case tsvToMarkdown // Reverse
}

func swapInputOutput() {
    // Swap content AND transformation direction
}
```

**Why:** Users think in both directions. Don't make them manually reverse.

---

## Tech Stack Decisions

| Choice                      | Reason                                   |
| --------------------------- | ---------------------------------------- |
| Swift + SwiftUI             | Mac-native performance, modern UI        |
| SwiftData                   | Local-first, privacy-focused persistence |
| NSPanel for floating window | Full control vs MenuBarExtra limitations |
| NSAttributedString          | Rich text support for transformations    |

---

## File Structure

```
Sources/
├── ClipApp.swift           # App entry point
├── AppDelegate.swift       # Menu bar + window lifecycle
├── FloatingPanel.swift     # Custom NSPanel config
├── Models/
│   └── Asset.swift         # SwiftData model
├── Views/
│   ├── ContentView.swift   # Main tab container
│   ├── AssetGridView.swift # Drag-and-drop asset manager
│   ├── TransformerView.swift # Text transformation UI
│   └── WindowDragView.swift  # Draggable header area
└── Utilities/
    ├── TableTransformer.swift    # MD ↔ CSV/TSV
    └── RichTextTransformer.swift # MD ↔ Rich Text
```

---

## Quick Reference

### Common Tasks

**Resize floating window:**

```swift
// AppDelegate.swift, line ~46
floatingPanel = FloatingPanel(
    contentRect: NSRect(x: 0, y: 0, width: 550, height: 750),
    //                                  ^^^       ^^^
)
```

**Add new transformation:**

1. Add case to `TransformType` enum
2. Add detection logic to `detectContentType()`
3. Add transform logic to `transform()`
4. Add reverse case to `swapInputOutput()`

**Debug window behavior:**

- Check `.level` (should be `.floating`)
- Check `.isMovableByWindowBackground` (false for drag-and-drop)
- Check activation policy (`.accessory` for menu bar apps)

---

## Future Considerations

- [ ] Autotext: Use Accessibility API for global text expansion
- [ ] AI Integration: Local (CoreML) vs Cloud (API) tradeoff
- [ ] iCloud Sync: SwiftData + CloudKit for cross-device assets
- [ ] Hotkey: Global shortcut to toggle panel (MASShortcut or native)

---

_Last Updated: 2025-11-22 (Session 6 Post-Journal)_

_"Every session makes this book better. Every mistake makes us wiser."_
