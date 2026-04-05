import Foundation
import AppKit
import ClipCore

// AppKit-dependent extension on RichTextTransformer (defined in ClipCore).
// These methods use NSFont, NSAttributedString, etc. and cannot live in ClipCore.
extension RichTextTransformer {

    // MARK: - Markdown to Rich Text

    static func markdownToRichText(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: .newlines)

        for line in lines {
            let attributedLine = parseMarkdownLine(line)
            result.append(attributedLine)
            result.append(NSAttributedString(string: "\n"))
        }

        return result
    }

    private static func parseMarkdownLine(_ line: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var currentText = line

        // Headers
        if currentText.hasPrefix("# ") {
            currentText = String(currentText.dropFirst(2))
            return NSAttributedString(string: currentText, attributes: [
                .font: NSFont.boldSystemFont(ofSize: 24)
            ])
        } else if currentText.hasPrefix("## ") {
            currentText = String(currentText.dropFirst(3))
            return NSAttributedString(string: currentText, attributes: [
                .font: NSFont.boldSystemFont(ofSize: 20)
            ])
        } else if currentText.hasPrefix("### ") {
            currentText = String(currentText.dropFirst(4))
            return NSAttributedString(string: currentText, attributes: [
                .font: NSFont.boldSystemFont(ofSize: 16)
            ])
        }

        // Lists
        if currentText.hasPrefix("- ") || currentText.hasPrefix("* ") {
            currentText = "• " + String(currentText.dropFirst(2))
        }

        result.append(parseInlineFormatting(currentText))
        return result
    }

    private static func parseInlineFormatting(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        // Bold: **text**
        if let boldRegex = try? NSRegularExpression(pattern: "\\*\\*([^*]+)\\*\\*") {
            for match in boldRegex.matches(in: text, range: fullRange).reversed() {
                if match.numberOfRanges >= 2 {
                    let content = (text as NSString).substring(with: match.range(at: 1))
                    let replacement = NSAttributedString(string: content, attributes: [
                        .font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
                    ])
                    result.replaceCharacters(in: match.range, with: replacement)
                }
            }
        }

        // Italic: *text*
        if let italicRegex = try? NSRegularExpression(pattern: "(?<!\\*)\\*([^*]+)\\*(?!\\*)") {
            for match in italicRegex.matches(in: result.string, range: NSRange(location: 0, length: result.length)).reversed() {
                if match.numberOfRanges >= 2 {
                    let content = (result.string as NSString).substring(with: match.range(at: 1))
                    let descriptor = NSFont.systemFont(ofSize: NSFont.systemFontSize).fontDescriptor.withSymbolicTraits(.italic)
                    let font = NSFont(descriptor: descriptor, size: NSFont.systemFontSize) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
                    let replacement = NSAttributedString(string: content, attributes: [.font: font])
                    result.replaceCharacters(in: match.range, with: replacement)
                }
            }
        }

        // Code: `text`
        if let codeRegex = try? NSRegularExpression(pattern: "`([^`]+)`") {
            for match in codeRegex.matches(in: result.string, range: NSRange(location: 0, length: result.length)).reversed() {
                if match.numberOfRanges >= 2 {
                    let content = (result.string as NSString).substring(with: match.range(at: 1))
                    let replacement = NSAttributedString(string: content, attributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                        .backgroundColor: NSColor.lightGray.withAlphaComponent(0.2)
                    ])
                    result.replaceCharacters(in: match.range, with: replacement)
                }
            }
        }

        return result
    }

    // MARK: - Rich Text to Markdown

    static func richTextToMarkdown(_ attributedString: NSAttributedString) -> String {
        var markdown = ""
        let string = attributedString.string

        attributedString.enumerateAttributes(in: NSRange(location: 0, length: attributedString.length), options: []) { attributes, range, _ in
            let substring = (string as NSString).substring(with: range)

            if let font = attributes[.font] as? NSFont {
                if font.pointSize >= 20 && font.fontDescriptor.symbolicTraits.contains(.bold) {
                    markdown += font.pointSize >= 24 ? "# \(substring)" : "## \(substring)"
                } else if font.fontDescriptor.symbolicTraits.contains(.bold) {
                    markdown += "**\(substring)**"
                } else if font.fontDescriptor.symbolicTraits.contains(.italic) {
                    markdown += "*\(substring)*"
                } else if font.familyName?.contains("Mono") == true || font.familyName?.contains("Courier") == true {
                    markdown += "`\(substring)`"
                } else {
                    markdown += substring
                }
            } else {
                markdown += substring
            }
        }

        return markdown
    }
}
