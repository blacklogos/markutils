# Phase 02 — ContentView Refactor

**Status:** pending
**Parent:** [plan.md](plan.md)

---

## Context Links

- `Sources/Views/ContentView.swift` — file being modified
- `Sources/Views/SidebarView.swift` — created in Phase 01
- `Sources/FloatingPanel.swift` — owns all window config post-refactor

---

## Overview

**Date:** 2026-04-26
**Description:** Strip the top HStack header, `WindowAccessor`, and `CircleButton` from `ContentView`. Replace with `HStack { SidebarView | Divider | tab content }`. Remove `edgesIgnoringSafeArea(.top)`.
**Priority:** P0 — the core bug fix
**Status:** pending

---

## Key Insights

1. `WindowAccessor` re-applies window config asynchronously (`DispatchQueue.main.async`). This races with `FloatingPanel.init`. Removing it entirely means `FloatingPanel.init` is the sole owner — race condition eliminated.
2. `edgesIgnoringSafeArea(.top)` was needed because the old layout pushed the header into the titlebar zone. With the sidebar layout, the safe area is respected normally — content starts below the titlebar frame naturally.
3. `CircleButton` is only used by the removed header. Delete it (YAGNI).
4. `MarkdownPreviewRouter.shared` observation (`onChange`) that switches to tab 1 must be preserved — it's used by the transformer preview feature.
5. Onboarding sheet `.sheet(isPresented: $showOnboarding)` must be preserved — triggered on first launch.
6. `⌘N` key absorb (`.keyboardShortcut("n", modifiers: .command)`) must be preserved or confirmed as still present.
7. The `@AppStorage("appTheme")` binding in `ContentView` can be removed — `SidebarView` reads the same `@AppStorage` key directly. Only keep it if `preferredColorScheme` modifier is applied on the root view (it must be — keep the binding for that one use).
8. `isPinned` `@State` stays in `ContentView` as `@State` — passed as `$isPinned` binding to `SidebarView`. `SidebarView` mutates it; `FloatingPanel` observes it separately via its own mechanism (check: `togglePin` calls `panel.level = .floating / .normal`). Confirm the pin toggle path still reaches the panel.

---

## Requirements

- Remove: `HStack` header, `WindowAccessor` struct, `CircleButton` struct, `edgesIgnoringSafeArea(.top)`.
- Add: `SidebarView(selectedTab: $selectedTab, isPinned: $isPinned)` as leading element of root `HStack`.
- Root `HStack` modifier: `.frame(maxWidth: .infinity, maxHeight: .infinity)`.
- Keep: `@AppStorage("appTheme")` (for `preferredColorScheme`), `@State isPinned`, `@State selectedTab`, onboarding sheet, `onChange(of: MarkdownPreviewRouter.shared....)`, keyboard shortcut absorb.
- `preferredColorScheme(appTheme.colorScheme)` stays on root `HStack`.
- No new `WindowAccessor` or any AppKit window manipulation in `ContentView`.

---

## Architecture

```swift
// ContentView.body (after refactor)
var body: some View {
    HStack(spacing: 0) {
        SidebarView(selectedTab: $selectedTab, isPinned: $isPinned)
        Divider()
        Group {
            switch selectedTab {
            case 0: AssetGridView()
            case 1: TransformerView()
            case 2: SocialMediaFormatterView()
            case 3: NotesView()
            default: AssetGridView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppColors.windowBackground)
    .preferredColorScheme(appTheme.colorScheme)
    .sheet(isPresented: $showOnboarding) { OnboardingView() }
    .onAppear { /* first-launch check */ }
    .onChange(of: MarkdownPreviewRouter.shared.pendingTab) { _, tab in
        if let tab { selectedTab = tab }
    }
    // ⌘N absorb if present
}
```

**Deleted from ContentView:**
- `struct CircleButton` (entire struct)
- `struct WindowAccessor` (entire struct — NSViewRepresentable)
- The `HStack { ... }` header section
- `.edgesIgnoringSafeArea(.top)` modifier
- Any `@State var showTrafficLights` or similar window-config state (verify existence first)

---

## Related Code Files

- `Sources/Views/AssetGridView.swift` — tab 0 content, no changes
- `Sources/Views/TransformerView.swift` — tab 1 content, no changes
- `Sources/Views/SocialMediaFormatterView.swift` — tab 2 content, no changes
- `Sources/Views/NotesView.swift` — tab 3 content, no changes
- `Sources/MarkdownPreviewRouter.swift` — `pendingTab` observation, no changes

---

## Implementation Steps

1. Open `Sources/Views/ContentView.swift`.
2. Delete `struct WindowAccessor` (find `NSViewRepresentable` conformance block — full struct).
3. Delete `struct CircleButton` (find by name — full struct).
4. In `body`, replace the entire `VStack { HStack header | Divider | Group switch }` with the `HStack` layout shown above.
5. Remove `.edgesIgnoringSafeArea(.top)` from any modifier chain.
6. Verify `@AppStorage("appTheme")` remains (needed for `preferredColorScheme`).
7. Verify `isPinned` toggle in `SidebarView` reaches `FloatingPanel`:
   - Check how `togglePin` currently works — likely calls `NSApp.windows.first` or uses a notification. If it called `WindowAccessor`-provided reference, that path is now broken — fix by using `NotificationCenter` post from `SidebarView` and observe in `AppDelegate` / `FloatingPanel`. Document the fix in this phase if needed.
8. `swift build` — resolve any missing reference errors.
9. Run `./scripts/verify_release.sh`.

---

## Todo

- [ ] Delete `struct WindowAccessor` from `ContentView.swift`
- [ ] Delete `struct CircleButton` from `ContentView.swift`
- [ ] Replace `VStack` body with `HStack { SidebarView | Divider | tab Group }` layout
- [ ] Remove `.edgesIgnoringSafeArea(.top)`
- [ ] Audit `isPinned` → panel level toggle path — fix if it used `WindowAccessor`
- [ ] `swift build` — clean compile
- [ ] `./scripts/verify_release.sh`

---

## Success Criteria

- App launches with no invisible header on first run.
- Tab switching works via sidebar nav items.
- Onboarding sheet still appears on first launch.
- `MarkdownPreviewRouter` tab switch still works.
- Theme toggle changes color scheme.
- Pin toggle changes window level (verify: pin → window stays on top of full-screen spaces).
- No AppKit window manipulation in `ContentView`.
- `swift build` + `verify_release.sh` pass.

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| `togglePin` path used `WindowAccessor`-provided window ref | Medium | Audit before delete; replace with `NotificationCenter` if needed |
| `onChange(of:)` API signature differs (macOS 14 two-param form) | Low | Keep existing signature — don't touch |
| Onboarding sheet breaks (relied on VStack safe area) | Low | Sheet is presented modally — layout-independent |
| Removing `edgesIgnoringSafeArea` adds unexpected padding | Low | `FloatingPanel` has `titlebarAppearsTransparent` — safe area is the transparent titlebar; content inside HStack starts at correct y |

---

## Security Considerations

None. Removing AppKit window manipulation reduces attack surface (less direct window API exposure from SwiftUI layer).

---

## Next Steps

Phase 03 — update `FloatingPanel` `minSize` to 500 pt width and run final verification.
