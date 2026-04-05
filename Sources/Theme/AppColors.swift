import SwiftUI

// Centralized warm minimal color palette.
// Light: creamy off-white tones (#FAF8F5 family).
// Dark: charcoal tones with warm tint (#1E1E1E family).
struct AppColors {

    static var windowBackground: Color { dynamic(light: "FAF8F5", dark: "1E1E1E") }
    static var editorBackground:  Color { dynamic(light: "F7F4EF", dark: "252525") }
    static var toolbarBackground: Color { dynamic(light: "F0EDE8", dark: "2A2A2A") }
    static var textPrimary:       Color { dynamic(light: "2C2C2C", dark: "E8E0D8") }
    static var textSecondary:     Color { Color(hex: "8A8078") }  // same in both modes
    static var divider:           Color { dynamic(light: "A08C7826", dark: "A08C781F") }
    static var activeTab:         Color { dynamic(light: "E8E2DA", dark: "3A3530") }

    // Warm amber accent (slightly lighter in dark mode)
    static var accent: Color { dynamic(light: "C47D4E", dark: "D4956A") }

    private static func dynamic(light: String, dark: String) -> Color {
        Color(NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(warmHex: dark) : NSColor(warmHex: light)
        })
    }
}

// MARK: - Hex convenience initializers

extension Color {
    init(hex: String) { self.init(NSColor(warmHex: hex)) }
}

extension NSColor {
    /// Accepts 6-char (#RRGGBB) or 8-char (#RRGGBBAA) hex strings, with or without leading #.
    convenience init(warmHex hex: String) {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let padded = h.count == 6 ? h + "FF" : h
        let v = UInt64(padded, radix: 16) ?? 0
        let r = CGFloat((v >> 24) & 0xFF) / 255
        let g = CGFloat((v >> 16) & 0xFF) / 255
        let b = CGFloat((v >>  8) & 0xFF) / 255
        let a = CGFloat( v        & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }
}
