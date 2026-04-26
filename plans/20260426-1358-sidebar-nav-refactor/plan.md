# Plan: Sidebar Nav Refactor

**Date:** 2026-04-26
**Status:** complete
**Scope:** Replace VStack titlebar-tab header with collapsible HStack sidebar, eliminating first-run header invisibility bug.

---

## Problem

`FloatingPanel.init` hides traffic lights + sets `fullSizeContentView` + `titlebarAppearsTransparent`. `ContentView` re-configures the same window via `WindowAccessor` (`DispatchQueue.main.async`) — race condition. The HStack header with `Picker` renders inside AppKit's titlebar zone and becomes invisible on first run. `edgesIgnoringSafeArea(.top)` pushes content to y=0, colliding with native titlebar frame.

**Root cause:** Two sites own the same window configuration. Fix: let `FloatingPanel.init` own all window config; `ContentView` becomes pure SwiftUI with no AppKit window access.

---

## Solution Summary

Move navigation from a top HStack header (subject to titlebar overlap) to a left-side sidebar (`SidebarView`). The root `ContentView` body becomes `HStack { SidebarView | Divider | tab content }` — no `edgesIgnoringSafeArea`, no `WindowAccessor`. Sidebar carries all nav + utility buttons previously in the header.

---

## Phases

| # | File | Status |
|---|------|--------|
| 1 | [phase-01-sidebar-view.md](phase-01-sidebar-view.md) | complete |
| 2 | [phase-02-content-view-refactor.md](phase-02-content-view-refactor.md) | complete |
| 3 | [phase-03-floating-panel-update.md](phase-03-floating-panel-update.md) | complete |

---

## Files Touched

| File | Change |
|------|--------|
| `Sources/Views/SidebarView.swift` | CREATE |
| `Sources/Views/ContentView.swift` | MODIFY — strip header + WindowAccessor + CircleButton |
| `Sources/FloatingPanel.swift` | MODIFY — minSize width 450 → 500 |

---

## Resolved Decisions

| # | Question | Decision |
|---|----------|----------|
| 1 | Keep `CircleButton`? | Delete — only used by removed header |
| 2 | Keep `WindowAccessor`? | Delete — single window config owner = `FloatingPanel.init` |
| 3 | Collapsed sidebar width? | 44 pt (fits SF Symbol at 20 pt + 12 pt padding each side) |
| 4 | Animation duration? | 0.2s `.easeInOut` — fast enough to feel snappy, slow enough to read |
| 5 | `edgesIgnoringSafeArea`? | Remove entirely — sidebar layout avoids titlebar zone naturally |

## Unresolved Questions

- Does removing `WindowAccessor` re-show of traffic lights affect any theme-change path? Verify in Phase 2 that theme toggle still works without the async window re-config.
- Is `isMovableByWindowBackground = false` still correct after sidebar takes over drag area via `WindowDragView`? Confirm drag still works on first run.
