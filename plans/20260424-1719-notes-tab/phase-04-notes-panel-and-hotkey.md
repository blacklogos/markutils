# Phase 04 — NotesPanel + ⌥A Global Hotkey
Context: [plan.md](plan.md) | [hotkey research](research/researcher-01-hotkey-and-keyword-expansion.md) | [panel research](research/researcher-02-panel-and-export.md)

## Overview
- Date: 2026-04-24
- Description: Second NSPanel hosting NotesView + ⌥A NSEvent global hotkey in AppDelegate (dedicated to Notes only)
- Priority: P1 — depends on Phase 03
- Status: Not Started
- Review: Pending

## Key Insights
- **NotesPanel** mirrors `FloatingPanel.swift` exactly — same styleMask, same `isReleasedWhenClosed = false`, same `canBecomeKey/Main`. Only difference: smaller default size (e.g. 500×600), different autosave name.
- **Hotkey approach**: `NSEvent.addGlobalMonitorForEvents` — consistent with existing Cmd+Shift+C pattern, no new entitlement. ⌥A is dedicated to NotesPanel only; main FloatingPanel retains its own toggle.
- **⌥A detection**: `event.modifierFlags.intersection([.command, .shift, .option, .control]) == [.option]` + `event.keyCode == 0` (A key).
- **Lazy instantiation**: `notesPanel` created on first hotkey press, not at app launch — matches deferred panel pattern.
- **Toggle logic**: `if notesPanel.isVisible { notesPanel.orderOut(nil) } else { notesPanel.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }`
- **Shared store**: `NSHostingView(rootView: NotesView().environment(NoteStore.shared))` — same `NoteStore.shared` as Tab 3.

## Requirements
- File: `Sources/NotesPanel.swift` — `NotesPanel: NSPanel` subclass
- `AppDelegate` changes: `var notesPanel: NotesPanel?`, second `globalHotkeyMonitor` for ⌥A, `toggleNotesPanel()` method
- Panel hosts `NotesView` via `NSHostingController`
- Minimal toolbar inside the panel: date label · Copy · Export · Pin (handled by NotesView's own toolbar — no extra header needed at NSPanel level)
- `@AppStorage("globalHotkeyKey")` stored but hardcoded to ⌥A (keyCode 0) for v1

## Architecture

```
Sources/NotesPanel.swift
└── class NotesPanel: NSPanel
    init(contentRect:backing:defer:)
    ├── super.init same styleMask as FloatingPanel
    ├── level = .floating
    ├── collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    ├── titleVisibility = .hidden / titlebarAppearsTransparent = true
    ├── isReleasedWhenClosed = false
    ├── hide traffic-light buttons
    ├── minSize = NSSize(width: 400, height: 500)
    └── setFrameAutosaveName("ClipNotesPanel")
    override canBecomeKey → true
    override canBecomeMain → true

AppDelegate additions
├── var notesPanel: NotesPanel?
├── private var notesPanelHotkeyMonitor: Any?
├── applicationDidFinishLaunching: register ⌥A monitor
├── applicationWillTerminate: NSEvent.removeMonitor(notesPanelHotkeyMonitor)
├── func createNotesPanel() — lazy, called once
│   └── notesPanel = NotesPanel(contentRect: NSRect(x:0 y:0 width:500 height:600), ...)
│       contentViewController = NSHostingController(rootView: NotesView().environment(NoteStore.shared))
│       center()
│       delegate = self
└── @objc func toggleNotesPanel()
    ├── if notesPanel == nil { createNotesPanel() }
    └── toggle isVisible
```

## Related Code Files
- `Sources/FloatingPanel.swift` — copy-paste base for NotesPanel
- `Sources/AppDelegate.swift` — existing hotkey monitor pattern (lines 89–94)
- `Sources/Views/NotesView.swift` — Phase 03 output, hosted here

## Implementation Steps

1. Create `Sources/NotesPanel.swift` — copy `FloatingPanel.swift`, rename class to `NotesPanel`, change autosave name, change `minSize` to `NSSize(width: 400, height: 500)`.

2. In `AppDelegate`:
   - Add `var notesPanel: NotesPanel?` and `private var notesPanelHotkeyMonitor: Any?`
   - In `applicationDidFinishLaunching`, after existing hotkey setup:
     ```swift
     notesPanelHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
         guard event.modifierFlags.intersection([.command, .shift, .option, .control]) == [.option],
               event.keyCode == 0 else { return }
         DispatchQueue.main.async { self?.toggleNotesPanel() }
     }
     ```
   - In `applicationWillTerminate`: `if let m = notesPanelHotkeyMonitor { NSEvent.removeMonitor(m) }`

3. Add `createNotesPanel()` private method — lazy init with `NSHostingController` wrapping `NotesView().environment(NoteStore.shared)`.

4. Add `@objc func toggleNotesPanel()` — creates panel if nil, then toggles visibility.

5. Add "Open Notes" to AppDelegate's status item menu (optional, low-priority) — `NSMenuItem(title: "Open Notes", action: #selector(toggleNotesPanel), keyEquivalent: "")`.

## Todo
- [ ] Create `Sources/NotesPanel.swift` (mirrors FloatingPanel)
- [ ] Add `notesPanel` + `notesPanelHotkeyMonitor` vars to AppDelegate
- [ ] Register ⌥A NSEvent global monitor in `applicationDidFinishLaunching`
- [ ] Remove monitor in `applicationWillTerminate`
- [ ] `createNotesPanel()` with NSHostingController + NoteStore.shared
- [ ] `toggleNotesPanel()` toggle logic
- [ ] (Optional) "Open Notes" menu item
- [ ] Manual test: press ⌥A → panel appears; press again → hides
- [ ] Run `./scripts/verify_release.sh`

## Success Criteria
- `NotesPanel` compiles without errors
- Pressing ⌥A from any app shows/hides the notes panel
- Panel persists position between shows (autosave frame)
- NoteStore changes in Tab 3 reflected in NotesPanel (shared singleton)
- Panel does not block main FloatingPanel interactions

## Risk Assessment
- **Medium:** Two floating panels at same `.floating` level may fight for key focus. Mitigation: `makeKeyAndOrderFront` only on the toggled panel; the other stays visible but non-key.
- **Low:** `NSEvent.addGlobalMonitorForEvents` requires Accessibility permission prompt on first use. Same as existing Cmd+Shift+C monitor — app already triggers this prompt.
- **Low:** Lazy `notesPanel` creation means first ⌥A press has slight delay. Acceptable for v1.

## Security Considerations
- Global key monitor reads all keystrokes system-wide — standard for menu-bar utilities; existing hotkey does same
- No keylogging beyond modifier+keyCode check; no content captured

## Next Steps
Phase 05 — ContentView wiring (runs in parallel with this phase after Phase 03 completes)
