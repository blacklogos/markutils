---
name: Global hotkey configurable via unvalidated UserDefaults
description: Any local process can write UserDefaults to remap Clip's global hotkey to a single unmodified key, capturing all keystrokes system-wide
type: todo
status: pending
priority: p2
issue_id: "005"
tags: [code-review, security]
dependencies: []
---

## Problem Statement

`AppDelegate` reads the global hotkey key code and modifier flags from `UserDefaults.standard` without validating that the modifier mask contains at least one modifier key. Any process running as the same user can write to the app's plist and set the hotkey to a bare, unmodified key — causing Clip's global event monitor to intercept and swallow keystrokes from all applications.

## Findings

**File:** `Sources/AppDelegate.swift` lines 137–141
```swift
let keyCode = UInt16(UserDefaults.standard.integer(forKey: "notesHotkeyKeyCode"))
let mods = NSEvent.ModifierFlags(rawValue: UInt(UserDefaults.standard.integer(forKey: "notesHotkeyModifiers")))
// No validation that mods is non-empty before registering the monitor
```

Reported by security-sentinel.

## Proposed Solutions

### Option A — Validate modifier mask before registering (Recommended)
```swift
let requiredModifiers: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
guard !mods.intersection(requiredModifiers).isEmpty else {
    // Fall back to default ⌥A
    registerDefaultHotkey()
    return
}
```
- Pros: Simple guard; matches macOS HIG hotkey requirements
- Effort: Small | Risk: Low

### Option B — Hardcode hotkey, remove UserDefaults persistence
Remove the configurable hotkey entirely; hardcode ⌥A.
- Pros: Zero attack surface
- Cons: Loses user-configurable hotkey feature
- Effort: Small | Risk: Low

## Acceptance Criteria
- [ ] Registering a hotkey with zero modifier flags is rejected and falls back to default
- [ ] Existing ⌥A hotkey continues to work

## Work Log
- 2026-04-26: Identified by security-sentinel during PR #15 review
