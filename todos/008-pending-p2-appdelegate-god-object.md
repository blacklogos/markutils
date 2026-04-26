---
name: AppDelegate has 9+ responsibilities — God Object
description: AppDelegate owns status item, two panels, three event monitors, shake detector, Sparkle, CLI install, export/import, theme, keyword panel; untestable and will keep growing
type: todo
status: pending
priority: p2
issue_id: "008"
tags: [code-review, architecture]
dependencies: []
---

## Problem Statement

After PR #15, `AppDelegate` manages: NSStatusItem + menu, FloatingPanel, NotesPanel, global mouse shake detector, global hotkey monitor (notes), local hotkey monitor (notes), Sparkle updater controller, CLI install dialog, vault export, vault import, theme observer, keyword reference panel toggle. That is 9+ distinct responsibilities in one class. The file will continue to grow with every new feature.

## Findings

**File:** `Sources/AppDelegate.swift`
- Lines 16–18: three stored event monitors
- Lines 103–122: hotkey registration
- PR #15 adds `notesPanel`, `notesPanelHotkeyMonitor`, `notesPanelLocalHotkeyMonitor`

Reported by architecture-strategist.

## Proposed Solutions

### Option A — Extract PanelCoordinator + MenuBarController
- `PanelCoordinator`: owns FloatingPanel + NotesPanel + all hotkey monitors + shake detector
- `MenuBarController`: owns NSStatusItem + menu construction
- `AppDelegate`: thin bootstrap that creates and wires the two coordinators

```swift
class AppDelegate {
    let panelCoordinator = PanelCoordinator()
    let menuBarController = MenuBarController()
    func applicationDidFinishLaunching(...) {
        menuBarController.setup()
        panelCoordinator.setup()
    }
}
```
- Pros: Testable; each class has one job; clear ownership of panels vs. menu
- Effort: Medium | Risk: Low

### Option B — Incremental extraction (pragmatic)
Extract only `installCLITool`, vault import/export into separate structs/functions called from AppDelegate. Leave panels in AppDelegate for now.
- Pros: Lower risk; can be done PR-by-PR
- Effort: Small | Risk: Low

## Acceptance Criteria
- [ ] AppDelegate < 150 lines after extraction
- [ ] Panel lifecycle and hotkey logic isolated in a single class
- [ ] No behavior changes visible to user

## Work Log
- 2026-04-26: Identified by architecture-strategist during PR #15 review
