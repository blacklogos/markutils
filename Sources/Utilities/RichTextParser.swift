import AppKit

struct RichTextParser {
    static func convertToBBCode(_ attributedString: NSAttributedString) -> String {
        var bbCode = ""
        
        attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length), options: []) { attributes, range, _ in
            let text = (attributedString.string as NSString).substring(with: range)
            var wrappedText = text
            
            // Handle Font Styles (Bold, Italic)
            if let font = attributes[.font] as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits
                
                if traits.contains(.italic) {
                    wrappedText = "[i]\(wrappedText)[/i]"
                }
                
                // Check for Bold (traits or weight)
                // Note: Some fonts might use a bold trait, others weight. Simple trait check is usually enough.
                if traits.contains(.bold) {
                    wrappedText = "[b]\(wrappedText)[/b]"
                }
            }
            
            // Handle Underline
            if let underline = attributes[.underlineStyle] as? Int, underline != 0 {
                wrappedText = "[u]\(wrappedText)[/u]"
            }
            
            // Handle Strikethrough
            if let strikethrough = attributes[.strikethroughStyle] as? Int, strikethrough != 0 {
                wrappedText = "[s]\(wrappedText)[/s]"
            }
            
            // Handle Color
            if let color = attributes[.foregroundColor] as? NSColor {
                // Convert NSColor to Hex
                if let hex = color.toHex() {
                    // Avoid redundant black/white if it matches theme? No, specific colors usually mean intent.
                    // But let's skip default text colors to avoid clutter.
                    // Simple check: if not standard label color.
                    // For now, let's output color if it's explicitly set and distinct.
                    // Actually, getting "standard" color is tricky. Let's just do it.
                    wrappedText = "[color=\(hex)]\(wrappedText)[/color]"
                }
            }
            
            // Handle Link
            if let link = attributes[.link] {
                let urlString: String
                if let url = link as? URL {
                    urlString = url.absoluteString
                } else if let str = link as? String {
                    urlString = str
                } else {
                    urlString = ""
                }
                
                if !urlString.isEmpty {
                    wrappedText = "[url=\(urlString)]\(wrappedText)[/url]"
                }
            }
            
            bbCode += wrappedText
        }
        
        return bbCode
    }
}

extension NSColor {
    func toHex() -> String? {
        guard let rgb = usingColorSpace(.sRGB) else { return nil }
        let r = Int(rgb.redComponent * 255)
        let g = Int(rgb.greenComponent * 255)
        let b = Int(rgb.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
