## Topic 1: Global Hotkey in Sandboxed macOS Menu-Bar App

**Best approach:** CGEventTap. Deprecated Carbon `RegisterHotKey` still works (used by VS Code, Slack) but not recommended. `NSEvent.addGlobalMonitorForEventsMatchingMask` is AppKit alternative but functionally similar to Carbon.

**Sandbox compatibility:** CGEventTap works with App Sandbox if you use TCC (Transparency, Consent, Control) via Input Monitoring permission. App Store requires sandbox; NSEvent uses broader Accessibility permission which also works in sandbox.

**RegisterHotKey vs NSEvent trade-off:**
- RegisterHotKey: narrowly scoped, older, no Accessibility permission needed
- NSEvent: modern AppKit, requires Accessibility, cleaner integration with SwiftUI
- CGEventTap: TCC-based (Input Monitoring), preferred for sandbox, reliable

**Detecting ⌥A (Option+A):**
```swift
// Using NSEvent monitor
let mask: NSEvent.EventTypeMask = .keyDown
NSEvent.addGlobalMonitorForEvents(matching: mask) { event in
    if event.modifierFlags.contains(.option) && event.keyCode == 0 {  // ⌥A
        // Toggle NSPanel show/hide
    }
}
```
Modifier flags: `.option`, `.shift`, `.command`, `.control`. KeyCode for A = 0 (use Xcode debugger to find others).

**Panel toggle from callback:**
```swift
if let panel = NSApplication.shared.windows.first(where: { $0 is FloatingPanel }) as? FloatingPanel {
    panel.setIsVisible(!panel.isVisible)
}
```

**Entitlement required:** For App Sandbox + Accessibility: `com.apple.security.automation.apple-events` in entitlements. For Input Monitoring: NSInputMonitoringAuthorizationLevel in Info.plist.

---

## Topic 2: Inline Keyword Expansion in SwiftUI TextEditor

**Approach:** `onChange(of:)` modifier detects text changes. Pattern matching identifies triggers (`::`/`[]`). Replace inline, then manually restore cursor position.

**Cursor preservation challenge:** SwiftUI TextEditor has no direct `UITextViewDelegate` equivalent on macOS. Text mutations reset cursor to end. Workaround: track cursor before mutation, calculate offset delta, restore after mutation.

```swift
@State var text = ""
@State var selectedRange = NSRange(location: 0, length: 0)

TextEditor(text: $text)
    .onChange(of: text) { oldText, newText in
        if newText.contains("::today") {
            let oldPos = selectedRange.location
            let replaced = newText.replacingOccurrences(of: "::today", with: Date().formatted())
            
            text = replaced
            // Restore cursor: oldPos + delta
            let delta = replaced.count - newText.count
            selectedRange.location = oldPos + delta
        }
    }
```

**Undo stack gotcha:** Each mutation via `$text` binding creates separate undo action. Batching undo transactions requires AppKit (NSUndoManager), not directly supported in SwiftUI. Workaround: defer mutations to next run loop to batch them.

**macOS 14+ TextEditor gotchas:**
- No TextSelection binding (iOS 18+). Must use NSTextView via NSViewRepresentable for fine-grained cursor control.
- onChange fires after binding updates; cursor already reset.
- TextField is simpler but single-line. TextEditor on macOS = wrapped NSTextView.

**Recommendation:** For robust keyword expansion, wrap NSTextView in NSViewRepresentable to access `selectedRange` directly and avoid re-binding cycles. Plain TextEditor insufficient for cursor preservation.

**Example GitHub reference:** netceteragroup/SwiftUI-TransformingTextField demonstrates cursor management pattern.

---

Sources:
- [AeroSpace CGEventTap discussion](https://github.com/nikitabobko/AeroSpace/issues/1012)
- [KeepAssXC global event monitoring](https://github.com/keepassxreboot/keepassxc/issues/3393)
- [Level Up Coding: Detect Global Key Events](https://levelup.gitconnected.com/swiftui-macos-detect-listen-to-global-key-events-two-ways-df19e565793d?gi=f144e197daf9)
- [Apple Developer: App Sandbox](https://developer.apple.com/documentation/security/app_sandbox_entitlements)
- [SwiftUI-TransformingTextField](https://github.com/netceteragroup/SwiftUI-TransformingTextField)
- [Mastering TextEditor in SwiftUI](https://artemnovichkov.com/blog/mastering-text-editor-in-swiftui)
- [macOS Accessibility Permissions](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html)
- [HotKey Library](https://github.com/soffes/HotKey)
