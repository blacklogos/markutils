# Phase 03 — FloatingPanel Update + Final Verification

**Status:** pending
**Parent:** [plan.md](plan.md)

---

## Context Links

- `Sources/FloatingPanel.swift` — file being modified
- `./scripts/verify_release.sh` — mandatory pre-completion gate

---

## Overview

**Date:** 2026-04-26
**Description:** Update `FloatingPanel.minSize` width from 450 → 500 to accommodate the sidebar (44–160 pt) plus content area. Run full verification.
**Priority:** P1 — polish + gate
**Status:** pending

---

## Key Insights

1. Collapsed sidebar = 44 pt. Content area minimum usable = ~320 pt (matches current TransformerView min). 44 + 1 (divider) + 320 = 365 pt — well under 450. Expanded sidebar = 160 pt. 160 + 1 + 320 = 481 pt — exceeds current 450 min. Set to 500 to give 19 pt breathing room.
2. Height minimum stays 400 pt — sidebar height is unconstrained, no change needed.
3. No other `FloatingPanel` changes required. Traffic light hiding and `titlebarAppearsTransparent` stay as-is — they are correct and no longer conflict with `ContentView` after `WindowAccessor` removal.
4. `isMovableByWindowBackground = false` stays — sidebar's `WindowDragView` handles dragging explicitly, which is correct.

---

## Requirements

- Change `minSize.width`: `450` → `500`.
- No other changes to `FloatingPanel.swift`.
- `./scripts/verify_release.sh` must pass before marking plan complete.

---

## Architecture

```swift
// FloatingPanel.swift — only change:
// Before:
self.minSize = NSSize(width: 450, height: 400)
// After:
self.minSize = NSSize(width: 500, height: 400)
```

---

## Related Code Files

- `Sources/FloatingPanel.swift` — single-line change

---

## Implementation Steps

1. Open `Sources/FloatingPanel.swift`.
2. Change `NSSize(width: 450, height: 400)` → `NSSize(width: 500, height: 400)`.
3. `swift build` — confirm clean.
4. Manual smoke test:
   a. Launch app — verify panel appears, header visible immediately (no first-run bug).
   b. Click each nav item — verify tab switches.
   c. Collapse sidebar (chevron) — verify width animates to 44 pt, icons remain visible.
   d. Expand sidebar — verify labels reappear.
   e. Toggle theme — verify color scheme changes.
   f. Toggle pin — verify window level changes (stays on top / normal).
   g. Resize window below 500 pt — verify resize is blocked.
5. Run `./scripts/verify_release.sh`.

---

## Todo

- [ ] Change `minSize` width to 500 in `FloatingPanel.swift`
- [ ] `swift build`
- [ ] Smoke test: launch, first-run header visible
- [ ] Smoke test: nav switching
- [ ] Smoke test: sidebar collapse/expand
- [ ] Smoke test: theme toggle
- [ ] Smoke test: pin toggle
- [ ] Smoke test: window resize floor
- [ ] `./scripts/verify_release.sh` — pass

---

## Success Criteria

- `verify_release.sh` exits 0.
- No first-run header invisibility bug reproducible.
- All smoke tests pass.
- Window resize floor is 500 pt wide.

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| `verify_release.sh` fails due to unrelated test | Low | Fix the failing test before closing the plan |
| Smoke test reveals pin toggle broken (Phase 02 risk materializes) | Medium | Fix in Phase 02 before reaching this phase |
| 500 pt width feels too wide on small screens | Low | Collapsing sidebar brings effective content width to ~455 pt; acceptable |

---

## Security Considerations

None. Single numeric constant change.

---

## Next Steps

Plan complete. Mark all phase statuses → `complete` in `plan.md` after `verify_release.sh` passes.
