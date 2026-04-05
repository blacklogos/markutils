import Foundation

// Converts text to Unicode-styled plain text for social media platforms (LinkedIn, Twitter, etc.)
// where markdown is not rendered but Unicode mathematical characters display styled text.
public struct UnicodeTextFormatter {

    public enum Style {
        case bold, italic, boldItalic, monospace, script, smallCaps, underline, strikethrough
    }

    // MARK: - Character Maps (lazily built)

    // Mathematical Bold: a-z → U+1D41A, A-Z → U+1D400, 0-9 → U+1D7CE
    private static let boldMap: [Character: Character] = {
        var map: [Character: Character] = [:]
        for i in 0..<26 {
            map[Character(Unicode.Scalar(0x61 + i)!)] = Character(Unicode.Scalar(0x1D41A + i)!)
            map[Character(Unicode.Scalar(0x41 + i)!)] = Character(Unicode.Scalar(0x1D400 + i)!)
        }
        for i in 0..<10 {
            map[Character(Unicode.Scalar(0x30 + i)!)] = Character(Unicode.Scalar(0x1D7CE + i)!)
        }
        return map
    }()

    // Mathematical Italic: a-z → U+1D44E (h → U+210E), A-Z → U+1D434
    private static let italicMap: [Character: Character] = {
        var map: [Character: Character] = [:]
        for i in 0..<26 {
            let toScalar: Unicode.Scalar = i == 7  // h
                ? Unicode.Scalar(0x210E)!
                : Unicode.Scalar(0x1D44E + i)!
            map[Character(Unicode.Scalar(0x61 + i)!)] = Character(toScalar)
            map[Character(Unicode.Scalar(0x41 + i)!)] = Character(Unicode.Scalar(0x1D434 + i)!)
        }
        return map
    }()

    // Mathematical Bold Italic: a-z → U+1D482, A-Z → U+1D468
    private static let boldItalicMap: [Character: Character] = {
        var map: [Character: Character] = [:]
        for i in 0..<26 {
            map[Character(Unicode.Scalar(0x61 + i)!)] = Character(Unicode.Scalar(0x1D482 + i)!)
            map[Character(Unicode.Scalar(0x41 + i)!)] = Character(Unicode.Scalar(0x1D468 + i)!)
        }
        return map
    }()

    // Mathematical Monospace: a-z → U+1D68A, A-Z → U+1D670, 0-9 → U+1D7F6
    private static let monospaceMap: [Character: Character] = {
        var map: [Character: Character] = [:]
        for i in 0..<26 {
            map[Character(Unicode.Scalar(0x61 + i)!)] = Character(Unicode.Scalar(0x1D68A + i)!)
            map[Character(Unicode.Scalar(0x41 + i)!)] = Character(Unicode.Scalar(0x1D670 + i)!)
        }
        for i in 0..<10 {
            map[Character(Unicode.Scalar(0x30 + i)!)] = Character(Unicode.Scalar(0x1D7F6 + i)!)
        }
        return map
    }()

    // Mathematical Script (with BMP fallbacks for unassigned slots)
    // Capitals: BMP exceptions for B, E, F, H, I, L, M, R
    // Smalls: BMP exceptions for e, g, o; gaps at positions for e(→212F), g(→210A), o(→2134)
    private static let scriptMap: [Character: Character] = {
        let upperBMP: [Int: UInt32] = [1: 0x212C, 4: 0x2130, 5: 0x2131, 7: 0x210B, 8: 0x2110, 11: 0x2112, 12: 0x2133, 17: 0x211B]
        let upperBase: UInt32 = 0x1D49C
        let lowerExact: [Int: UInt32] = [
            0: 0x1D4B6, 1: 0x1D4B7, 2: 0x1D4B8, 3: 0x1D4B9,
            4: 0x212F,             // e
            5: 0x1D4BB,
            6: 0x210A,             // g
            7: 0x1D4BD, 8: 0x1D4BE, 9: 0x1D4BF,
            10: 0x1D4C0, 11: 0x1D4C1, 12: 0x1D4C2, 13: 0x1D4C3,
            14: 0x2134,            // o
            15: 0x1D4C5, 16: 0x1D4C6, 17: 0x1D4C7, 18: 0x1D4C8, 19: 0x1D4C9,
            20: 0x1D4CA, 21: 0x1D4CB, 22: 0x1D4CC, 23: 0x1D4CD, 24: 0x1D4CE, 25: 0x1D4CF
        ]

        var map: [Character: Character] = [:]
        for i in 0..<26 {
            let toValue = upperBMP[i] ?? (upperBase + UInt32(i))
            map[Character(Unicode.Scalar(0x41 + i)!)] = Character(Unicode.Scalar(toValue)!)
        }
        for i in 0..<26 {
            if let toValue = lowerExact[i] {
                map[Character(Unicode.Scalar(0x61 + i)!)] = Character(Unicode.Scalar(toValue)!)
            }
        }
        return map
    }()

    // Small Caps: lowercase → Latin small cap variants
    private static let smallCapsMap: [Character: Character] = {
        let pairs: [(UInt32, UInt32)] = [
            (0x61, 0x1D00), // a → ᴀ
            (0x62, 0x0299), // b → ʙ
            (0x63, 0x1D04), // c → ᴄ
            (0x64, 0x1D05), // d → ᴅ
            (0x65, 0x1D07), // e → ᴇ
            (0x66, 0xA730), // f → ꜰ
            (0x67, 0x0262), // g → ɢ
            (0x68, 0x029C), // h → ʜ
            (0x69, 0x026A), // i → ɪ
            (0x6A, 0x1D0A), // j → ᴊ
            (0x6B, 0x1D0B), // k → ᴋ
            (0x6C, 0x029F), // l → ʟ
            (0x6D, 0x1D0D), // m → ᴍ
            (0x6E, 0x0274), // n → ɴ
            (0x6F, 0x1D0F), // o → ᴏ
            (0x70, 0x1D18), // p → ᴘ
            // q: no standard small cap, keep as-is
            (0x72, 0x0280), // r → ʀ
            (0x73, 0xA731), // s → ꜱ
            (0x74, 0x1D1B), // t → ᴛ
            (0x75, 0x1D1C), // u → ᴜ
            (0x76, 0x1D20), // v → ᴠ
            (0x77, 0x1D21), // w → ᴡ
            // x: no standard small cap
            (0x79, 0x028F), // y → ʏ
            (0x7A, 0x1D22), // z → ᴢ
        ]
        var map: [Character: Character] = [:]
        for (from, to) in pairs {
            map[Character(Unicode.Scalar(from)!)] = Character(Unicode.Scalar(to)!)
        }
        return map
    }()

    // Reverse map: styled → ASCII (built from all forward maps, used in revertToPlain)
    private static let reverseMap: [Character: Character] = {
        var map: [Character: Character] = [:]
        let forwardMaps = [boldMap, italicMap, boldItalicMap, monospaceMap, scriptMap, smallCapsMap]
        for fwd in forwardMaps {
            for (plain, styled) in fwd {
                map[styled] = plain
            }
        }
        return map
    }()

    // MARK: - Apply Style

    /// Applies a Unicode style to all alphanumeric characters in `text`. Non-mapped chars pass through unchanged.
    public static func apply(_ style: Style, to text: String) -> String {
        switch style {
        case .bold:        return text.map { boldMap[$0].map(String.init) ?? String($0) }.joined()
        case .italic:      return text.map { italicMap[$0].map(String.init) ?? String($0) }.joined()
        case .boldItalic:  return text.map { boldItalicMap[$0].map(String.init) ?? String($0) }.joined()
        case .monospace:   return text.map { monospaceMap[$0].map(String.init) ?? String($0) }.joined()
        case .script:      return text.map { scriptMap[$0].map(String.init) ?? String($0) }.joined()
        case .smallCaps:   return text.map { smallCapsMap[$0].map(String.init) ?? String($0) }.joined()
        case .underline:
            // Insert combining underline (U+0332) after each character
            return text.unicodeScalars.map { String($0) + "\u{0332}" }.joined()
        case .strikethrough:
            // Insert combining strikethrough (U+0336) after each character
            return text.unicodeScalars.map { String($0) + "\u{0336}" }.joined()
        }
    }

    // MARK: - Revert to Plain

    /// Strips all Unicode styling (bold/italic/mono/script/smallCaps/underline/strikethrough) back to ASCII.
    public static func revertToPlain(_ text: String) -> String {
        // Remove combining overlay characters first
        let stripped = text
            .replacingOccurrences(of: "\u{0332}", with: "")
            .replacingOccurrences(of: "\u{0336}", with: "")
        // Reverse-map styled chars to plain ASCII
        return String(stripped.map { reverseMap[$0] ?? $0 })
    }

    // MARK: - Markdown → Unicode

    /// Converts Markdown-formatted text to Unicode-styled plain text suitable for social media.
    /// Handles: headers, bold/italic/monospace/strikethrough inline, bullet lists, blockquotes,
    /// horizontal rules, links, and embedded tables.
    public static func markdownToUnicode(_ markdown: String) -> String {
        var output = ""
        let lines = markdown.components(separatedBy: .newlines)
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Embedded table: collect consecutive pipe-starting lines
            if trimmed.hasPrefix("|") {
                var tableLines: [String] = []
                while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    tableLines.append(lines[i])
                    i += 1
                }
                output += markdownTableToASCII(tableLines.joined(separator: "\n")) + "\n"
                continue
            }

            // Horizontal rule
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                output += "─────────────────\n"
                i += 1; continue
            }

            // Headers
            if trimmed.hasPrefix("### ") {
                let content = String(trimmed.dropFirst(4))
                output += apply(.italic, to: content) + "\n"
                i += 1; continue
            }
            if trimmed.hasPrefix("## ") {
                let content = String(trimmed.dropFirst(3))
                output += apply(.bold, to: content) + "\n"
                i += 1; continue
            }
            if trimmed.hasPrefix("# ") {
                let content = String(trimmed.dropFirst(2))
                output += apply(.bold, to: content.uppercased()) + "\n"
                i += 1; continue
            }

            // Blockquote
            if trimmed.hasPrefix("> ") {
                output += "│ " + convertInline(String(trimmed.dropFirst(2))) + "\n"
                i += 1; continue
            }
            if trimmed.hasPrefix(">") {
                output += "│ " + convertInline(String(trimmed.dropFirst(1))) + "\n"
                i += 1; continue
            }

            // Unordered list
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                output += "• " + convertInline(String(trimmed.dropFirst(2))) + "\n"
                i += 1; continue
            }

            // Ordered list: keep numbering, just convert inline
            if trimmed.range(of: "^\\d+\\. ", options: .regularExpression) != nil {
                output += convertInline(trimmed) + "\n"
                i += 1; continue
            }

            // Regular line
            output += convertInline(trimmed) + "\n"
            i += 1
        }

        return output.trimmingCharacters(in: .newlines)
    }

    // MARK: - Markdown Table → ASCII Box

    /// Converts a Markdown table to an ASCII box-drawing table.
    /// Input may be just the table lines or full text containing table lines.
    public static func markdownTableToASCII(_ markdown: String) -> String {
        let allLines = markdown.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        // Split into table segments and non-table lines
        var segments: [Either] = []
        var tableAccum: [String] = []

        enum Either { case table([String]); case text(String) }

        for line in allLines {
            if line.hasPrefix("|") {
                tableAccum.append(line)
            } else {
                if !tableAccum.isEmpty {
                    segments.append(.table(tableAccum))
                    tableAccum = []
                }
                segments.append(.text(line))
            }
        }
        if !tableAccum.isEmpty { segments.append(.table(tableAccum)) }

        return segments.map { seg -> String in
            switch seg {
            case .text(let s): return s
            case .table(let lines): return renderBoxTable(lines)
            }
        }.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static func convertInline(_ text: String) -> String {
        var s = text

        // Process in order: longest/specific patterns first to avoid partial matches
        s = regexApply("\\*\\*\\*(.+?)\\*\\*\\*", in: s) { apply(.boldItalic, to: $0) }
        s = regexApply("\\*\\*(.+?)\\*\\*",        in: s) { apply(.bold, to: $0) }
        s = regexApply("(?<!\\*)\\*([^*\n]+?)\\*(?!\\*)", in: s) { apply(.italic, to: $0) }
        s = regexApply("(?<![\\w_])_([^_\n]+?)_(?![\\w_])", in: s) { apply(.italic, to: $0) }
        s = regexApply("`([^`\n]+)`",             in: s) { apply(.monospace, to: $0) }
        s = regexApply("~~(.+?)~~",               in: s) { apply(.strikethrough, to: $0) }
        s = regexApplyLink(s)

        return s
    }

    /// Applies `transform` to capture group 1 of each match, iterating right-to-left for safe NSRange reuse.
    private static func regexApply(_ pattern: String, in text: String, transform: (String) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).reversed()
        var result = text
        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            let capture = (text as NSString).substring(with: match.range(at: 1))
            result = (result as NSString).replacingCharacters(in: match.range, with: transform(capture))
        }
        return result
    }

    /// Converts [text](url) links → "text (url)"
    private static func regexApplyLink(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)") else { return text }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).reversed()
        var result = text
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let linkText = (text as NSString).substring(with: match.range(at: 1))
            let url = (text as NSString).substring(with: match.range(at: 2))
            result = (result as NSString).replacingCharacters(in: match.range, with: "\(linkText) (\(url))")
        }
        return result
    }

    private static func parseTableRow(_ line: String) -> [String] {
        line.trimmingCharacters(in: .whitespaces)
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func renderBoxTable(_ lines: [String]) -> String {
        var headerRows: [[String]] = []
        var bodyRows: [[String]] = []
        var separatorFound = false

        for line in lines {
            let cells = parseTableRow(line)
            let isSep = !cells.isEmpty && cells.allSatisfy { $0.allSatisfy { $0 == "-" || $0 == ":" } }
            if isSep {
                separatorFound = true
            } else if separatorFound {
                bodyRows.append(cells)
            } else {
                headerRows.append(cells)
            }
        }

        guard !headerRows.isEmpty || !bodyRows.isEmpty else { return lines.joined(separator: "\n") }

        // Normalize column count
        let colCount = (headerRows + bodyRows).map(\.count).max() ?? 0
        guard colCount > 0 else { return lines.joined(separator: "\n") }

        func normalize(_ row: [String]) -> [String] {
            var r = row; while r.count < colCount { r.append("") }; return r
        }
        let hNorm = headerRows.map(normalize)
        let bNorm = bodyRows.map(normalize)

        // Column widths (character count, acceptable for monospace hint)
        let colWidths = (0..<colCount).map { col in
            (hNorm + bNorm).map { $0[col].count }.max() ?? 0
        }

        func hLine(l: Character, j: Character, r: Character, f: Character) -> String {
            let segs = colWidths.map { String(repeating: String(f), count: $0 + 2) }
            return String(l) + segs.joined(separator: String(j)) + String(r)
        }

        func row(_ cells: [String]) -> String {
            let parts = cells.enumerated().map { i, c in
                " " + c + String(repeating: " ", count: max(0, colWidths[i] - c.count)) + " "
            }
            return "│" + parts.joined(separator: "│") + "│"
        }

        var out = hLine(l: "┌", j: "┬", r: "┐", f: "─") + "\n"

        for r in hNorm { out += row(r) + "\n" }

        if !hNorm.isEmpty && !bNorm.isEmpty {
            out += hLine(l: "╞", j: "╪", r: "╡", f: "═") + "\n"
        } else if !hNorm.isEmpty {
            out += hLine(l: "└", j: "┴", r: "┘", f: "─")
            return out
        }

        for (i, r) in bNorm.enumerated() {
            out += row(r) + "\n"
            if i < bNorm.count - 1 {
                out += hLine(l: "├", j: "┼", r: "┤", f: "─") + "\n"
            }
        }

        out += hLine(l: "└", j: "┴", r: "┘", f: "─")
        return out
    }
}
