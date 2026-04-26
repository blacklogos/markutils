# Phase 01 — Create SidebarView

**Status:** pending
**Parent:** [plan.md](plan.md)

---

## Context Links

- `Sources/Views/ContentView.swift` — tab constants, AppTheme enum, isPinned logic being migrated here
- `Sources/Theme/AppColors.swift` — `toolbarBackground`, `activeTab`, `accent`, `textSecondary`
- `Sources/Views/WindowDragView.swift` — drag handle to overlay at top of sidebar
- `Sources/FloatingPanel.swift` — window context (non-activating panel, fullSizeContentView)

---

## Overview

**Date:** 2026-04-26
**Description:** Create `Sources/Views/SidebarView.swift` — a collapsible left-rail nav component that replaces the top HStack header. Carries all navigation + utility controls previously in the header.
**Priority:** P0 — prerequisite for Phase 2
**Status:** pending

---

## Key Insights

1. Since the panel uses `fullSizeContentView + titlebarAppearsTransparent`, the sidebar's top edge sits at y=0 (under the transparent titlebar area). The drag handle (`WindowDragView`) at the top of the sidebar doubles as the window drag area — consistent with current `WindowDragView` usage.
2. Collapsed width 44 pt = 20 pt icon + 12 pt padding × 2. Matches standard macOS compact sidebar convention (e.g., Finder sidebar collapsed).
3. Expanded width 160 pt fits icon + label for all four nav items without truncation at the default font size (13 pt).
4. `@AppStorage("sidebarCollapsed")` persists collapse state across launches — YAGNI: no migration needed, defaults to `false`.
5. `AppTheme` and `isPinned` logic currently live in `ContentView`. Move the `@AppStorage("appTheme")` binding into `SidebarView` directly (it's `@AppStorage`, so both views reading the same key is fine — no prop drilling needed for theme).
6. `AppColors.accent` tint on selected icon provides sufficient visual affordance without needing a colored background pill — keeps sidebar visually quiet.

---

## Requirements

- Collapsible: 160 pt expanded ↔ 44 pt collapsed, animated `.easeInOut(duration: 0.2)`.
- Four nav items in order: Assets (0), Transform (1), Formatter (2), Notes (3).
- Selected item: `AppColors.activeTab` background + `AppColors.accent` icon tint.
- Unselected item: no background + `AppColors.textSecondary` icon tint.
- Bottom controls: theme cycle, pin toggle, chevron collapse toggle.
- Top area: `WindowDragView` overlay for window drag + paperclip icon + "Clip" label (hidden when collapsed).
- Background: `AppColors.toolbarBackground`.
- No `Divider` inside sidebar — divider between sidebar and content goes in `ContentView`.
- Labels hidden (not just opacity-0) when collapsed to avoid ghost tap targets.

---

## Architecture

```swift
// Sources/Views/SidebarView.swift

struct SidebarView: View {
    @AppStorage("sidebarCollapsed") private var isCollapsed = false
    @Binding var selectedTab: Int
    @Binding var isPinned: Bool
    @AppStorage("appTheme") private var appTheme: ContentView.AppTheme = .system

    private let expandedWidth: CGFloat = 160
    private let collapsedWidth: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            // Header: drag handle + branding
            headerSection

            Divider()

            // Nav items
            VStack(spacing: 2) {
                ForEach(navItems) { item in
                    NavItemView(item: item, isSelected: selectedTab == item.index,
                                isCollapsed: isCollapsed) {
                        selectedTab = item.index
                    }
                }
            }
            .padding(.vertical, 8)

            Spacer()

            Divider()

            // Bottom controls
            bottomControls
        }
        .frame(width: isCollapsed ? collapsedWidth : expandedWidth)
        .background(AppColors.toolbarBackground)
        .animation(.easeInOut(duration: 0.2), value: isCollapsed)
    }
}

// NavItem model (file-private)
private struct NavItem: Identifiable {
    let id = UUID()
    let index: Int
    let icon: String
    let label: String
}

private let navItems: [NavItem] = [
    NavItem(index: 0, icon: "square.grid.2x2", label: "Assets"),
    NavItem(index: 1, icon: "arrow.left.arrow.right", label: "Transform"),
    NavItem(index: 2, icon: "textformat.abc", label: "Formatter"),
    NavItem(index: 3, icon: "square.and.pencil", label: "Notes"),
]
```

**headerSection:** `ZStack` — `WindowDragView()` fills full area (tap-through for SwiftUI buttons underneath via `.allowsHitTesting(false)` on the drag view), overlaid with `HStack { Image("paperclip") + Text("Clip") }`. Text hidden when `isCollapsed`.

**NavItemView:** `Button` with `HStack { Image(systemName:) + Text(label) }`. Apply `.frame(maxWidth: .infinity, alignment: .leading)` so tap target fills row. Conditional padding so icon stays centered in 44 pt column when collapsed.

**bottomControls:** `VStack(spacing: 4)` — three icon buttons stacked. When collapsed, labels absent; icons stay centered. Chevron icon: `chevron.left` expanded, `chevron.right` collapsed.

---

## Related Code Files

- `Sources/Views/ContentView.swift:AppTheme` — `SidebarView` imports this enum; defined in `ContentView.swift` (no move needed unless scoping becomes awkward).
- `Sources/Views/WindowDragView.swift` — used as drag overlay in header.
- `Sources/Theme/AppColors.swift` — `toolbarBackground`, `activeTab`, `accent`, `textSecondary`.

---

## Implementation Steps

1. Create `Sources/Views/SidebarView.swift` with the structure above.
2. Define `NavItem` as a file-private struct (not exported — YAGNI).
3. Implement `headerSection` computed var: `ZStack` with `WindowDragView().allowsHitTesting(false)` + branding HStack.
4. Implement `NavItemView` as a file-private `View` struct.
5. Implement `bottomControls`: reuse `cycleTheme()`, `togglePin()` logic from `ContentView.AppTheme` extension — call the same `appTheme.cycleTheme()` / `isPinned.toggle()` pattern.
6. Wire chevron toggle to `withAnimation { isCollapsed.toggle() }`.
7. Build (`swift build`) — no tests needed for pure layout.

---

## Todo

- [ ] Create `Sources/Views/SidebarView.swift`
- [ ] Implement `headerSection` with `WindowDragView` overlay
- [ ] Implement `NavItemView` (file-private)
- [ ] Implement `bottomControls`
- [ ] Verify `AppTheme` enum is accessible from `SidebarView` (same module — it is, no import needed)
- [ ] `swift build` — confirm no compile errors

---

## Success Criteria

- `SidebarView` compiles cleanly as a standalone file.
- Nav selection changes `selectedTab` binding correctly.
- Collapse animation runs at 0.2s.
- Sidebar width is exactly 160 / 44 pt at expanded / collapsed states.
- Bottom controls mirror header button behavior exactly.

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| `AppTheme` enum not accessible (scoping) | Low | Both files in same module target; no issue |
| `WindowDragView` hit-testing blocks nav buttons | Low | Apply `.allowsHitTesting(false)` to `WindowDragView` layer only |
| Sidebar clips content during animation | Low | `clipped()` on root + `overflow: hidden` equivalent in SwiftUI is default |

---

## Security Considerations

None. Pure UI component, no data access, no persistence beyond `@AppStorage` boolean.

---

## Next Steps

Phase 02 — refactor `ContentView` to use `SidebarView` and remove `WindowAccessor` + header.
