---
module: Clip
date: 2026-04-05
problem_type: best_practice
component: tooling
symptoms:
  - "Hardcoded NSColor system colors ignore app's warm custom palette in both light and dark modes"
  - "SwiftUI Color(hex:) has no built-in light/dark variant — single hex looks wrong in one mode"
  - "Custom dark-mode overrides via @Environment(\.colorScheme) require view-level state; don't work in static contexts"
root_cause: wrong_api
resolution_type: code_fix
severity: medium
tags: [swiftui, nscolor, dark-mode, dynamic-color, macos, appcolors, warm-palette]
---

# Best Practice: Dynamic Light/Dark Color Palette in SwiftUI/AppKit via NSColor Dynamic Provider

## Problem

When building a custom color palette (e.g., warm minimal: `#FAF8F5` light, `#1E1E1E` dark),
naively using separate `Color` values and switching on `@Environment(\.colorScheme)` only works
in `View` context. Static properties on a `struct AppColors` can't access environment.

Additionally, `Color(hex:)` initializers produce a static color — it doesn't respond to the
system's light/dark switch.

## Environment

- Module: Clip (macOS menu bar utility)
- Language: Swift 5.9 / SwiftUI, macOS 14+
- Affected Component: `Sources/Theme/AppColors.swift`, all view files
- Date: 2026-04-05

## Symptoms

- Custom warm background shows in light mode but reverts to system default in dark mode.
- `@Environment(\.colorScheme)` switch inside `AppColors` static var → compiler error (no environment).
- SwiftUI previews look fine; runtime dark mode switch produces wrong color.

## What Didn't Work

**Attempted: Environment-based switch in view**
```swift
// In a view:
.background(colorScheme == .dark ? Color(hex: "1E1E1E") : Color(hex: "FAF8F5"))
```
- **Why it failed:** Repetitive; requires threading `colorScheme` through every call site;
  misses non-View contexts (e.g., NSTextView background set in `makeNSView`).

**Attempted: Asset catalog color set**
- Would work, but requires Xcode project structure. This project uses `swift build` / SPM only —
  no `.xcassets` support without adding resource bundle complexity.

## Solution

Use `NSColor`'s `dynamicProvider` initializer, which is evaluated at draw time with the current
`NSAppearance`:

```swift
// AppColors.swift
struct AppColors {
    static var windowBackground: Color { dynamic(light: "FAF8F5", dark: "1E1E1E") }
    static var editorBackground:  Color { dynamic(light: "F7F4EF", dark: "252525") }
    static var toolbarBackground: Color { dynamic(light: "F0EDE8", dark: "2A2A2A") }
    static var accent:            Color { dynamic(light: "C47D4E", dark: "D4956A") }
    // ...

    private static func dynamic(light: String, dark: String) -> Color {
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(warmHex: dark) : NSColor(warmHex: light)
        })
    }
}

// Hex initializer (6-char RRGGBB or 8-char RRGGBBAA, with or without #)
extension NSColor {
    convenience init(warmHex hex: String) {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let padded = h.count == 6 ? h + "FF" : h
        let v = UInt64(padded, radix: 16) ?? 0
        // Break into separate vars — Swift type-checker struggles with inline arithmetic
        let r = CGFloat((v >> 24) & 0xFF) / 255
        let g = CGFloat((v >> 16) & 0xFF) / 255
        let b = CGFloat((v >>  8) & 0xFF) / 255
        let a = CGFloat( v        & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }
}
```

Usage in views — no environment needed:
```swift
.background(AppColors.toolbarBackground)
.foregroundStyle(AppColors.textSecondary)
```

## Why This Works

1. `NSColor(name:dynamicProvider:)` stores the closure and re-evaluates it each time the
   color is drawn, using the *current* `NSAppearance` at draw time — not at init time.
2. `appearance.bestMatch(from: [.aqua, .darkAqua])` correctly resolves both system dark mode
   and app-level `preferredColorScheme` override (`.dark` → `.darkAqua`).
3. `Color(NSColor(...))` bridges to SwiftUI transparently — SwiftUI re-draws on appearance change.
4. The alpha-included 8-char hex variant allows encoding semi-transparent colors (e.g., dividers
   at 15% opacity) in the same centralised palette without separate opacity modifiers.

**Gotcha — type-checker complexity:** Swift's type inference on chained CGFloat arithmetic inside
`self.init(...)` often fails with "unable to type-check in reasonable time". Break computed values
into separate `let` constants before the `init` call.

## Prevention

- Always use `NSColor(name:dynamicProvider:)` for any custom color that must respect light/dark.
- Keep all colors in a single `AppColors` struct — never scatter `Color(hex:)` across views.
- For alpha-encoded colors use 8-char hex (RRGGBBAA) to keep the palette self-documenting.
- Break intermediate `CGFloat` arithmetic into separate vars to avoid Swift type-checker timeouts.
- `srgbRed:` (lowercase 'rgb') is the correct Swift label; `sRGBRed:` is wrong and won't compile.

## Related Issues

No related issues documented yet.
