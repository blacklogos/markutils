import SwiftUI

// Mock theme to support future styling updates
struct SlideTheme: Hashable {
    let backgroundColor: Color
    let titleColor: Color
    let bodyColor: Color
    let fontName: String
    
    // Manual Hashable conformance because Color is not Hashable by default in older SwiftUI versions, 
    // but in recent ones it might be. However, Color(nsColor: ...) wraps NSColor.
    // The safest way is to hash the description or just use an ID if we had one.
    // Let's implement a simple hash based on fontName + description for now, or just Equatable.
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(fontName)
        hasher.combine(backgroundColor.description)
        hasher.combine(titleColor.description)
    }
    
    static func == (lhs: SlideTheme, rhs: SlideTheme) -> Bool {
        return lhs.fontName == rhs.fontName &&
               lhs.backgroundColor.description == rhs.backgroundColor.description &&
               lhs.titleColor.description == rhs.titleColor.description
    }
    
    static let swiss = SlideTheme(
        backgroundColor: .white,
        titleColor: Color(red: 0.8, green: 0.1, blue: 0.1), // Swiss Red
        bodyColor: .black,
        fontName: "Helvetica Neue"
    )
    
    static let midnight = SlideTheme(
        backgroundColor: Color(red: 0.1, green: 0.1, blue: 0.2), // Deep Blue
        titleColor: .white,
        bodyColor: Color(red: 0.9, green: 0.9, blue: 0.95),
        fontName: "Avenir Next"
    )
    
    static let terminal = SlideTheme(
        backgroundColor: .black,
        titleColor: .green,
        bodyColor: .green,
        fontName: "Courier New"
    )
    
    static let paper = SlideTheme(
        backgroundColor: Color(red: 0.98, green: 0.96, blue: 0.93), // Cream
        titleColor: Color(red: 0.2, green: 0.2, blue: 0.2),
        bodyColor: Color(red: 0.1, green: 0.1, blue: 0.1),
        fontName: "Georgia"
    )
    
    static let classic = SlideTheme(
        backgroundColor: .white,
        titleColor: .black,
        bodyColor: .black,
        fontName: "Arial"
    )
    
    static let modern = SlideTheme(
        backgroundColor: Color(nsColor: .windowBackgroundColor),
        titleColor: .primary,
        bodyColor: .secondary,
        fontName: "San Francisco"
    )
    
    static let dark = SlideTheme(
        backgroundColor: .black,
        titleColor: .white,
        bodyColor: .gray,
        fontName: "Helvetica"
    )
}
