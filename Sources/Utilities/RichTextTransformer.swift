import Foundation
import AppKit

struct RichTextTransformer {
    
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
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 24)
            ]
            return NSAttributedString(string: currentText, attributes: attrs)
        } else if currentText.hasPrefix("## ") {
            currentText = String(currentText.dropFirst(3))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 20)
            ]
            return NSAttributedString(string: currentText, attributes: attrs)
        } else if currentText.hasPrefix("### ") {
            currentText = String(currentText.dropFirst(4))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 16)
            ]
            return NSAttributedString(string: currentText, attributes: attrs)
        }
        
        // Lists
        if currentText.hasPrefix("- ") || currentText.hasPrefix("* ") {
            currentText = "• " + String(currentText.dropFirst(2))
        }
        
        // Parse inline formatting
        result.append(parseInlineFormatting(currentText))
        
        return result
    }
    
    private static func parseInlineFormatting(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        
        // Bold: **text**
        let boldPattern = "\\*\\*([^*]+)\\*\\*"
        if let boldRegex = try? NSRegularExpression(pattern: boldPattern) {
            let matches = boldRegex.matches(in: text, range: fullRange).reversed()
            for match in matches {
                if match.numberOfRanges >= 2 {
                    let contentRange = match.range(at: 1)
                    let content = (text as NSString).substring(with: contentRange)
                    let replacement = NSAttributedString(string: content, attributes: [
                        .font: NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
                    ])
                    result.replaceCharacters(in: match.range, with: replacement)
                }
            }
        }
        
        // Italic: *text*
        let italicPattern = "(?<!\\*)\\*([^*]+)\\*(?!\\*)"
        if let italicRegex = try? NSRegularExpression(pattern: italicPattern) {
            let matches = italicRegex.matches(in: result.string, range: NSRange(location: 0, length: result.length)).reversed()
            for match in matches {
                if match.numberOfRanges >= 2 {
                    let contentRange = match.range(at: 1)
                    let content = (result.string as NSString).substring(with: contentRange)
                    let replacement = NSAttributedString(string: content, attributes: [
                        .font: NSFont(descriptor: NSFont.systemFont(ofSize: NSFont.systemFontSize).fontDescriptor.withSymbolicTraits(.italic), size: NSFont.systemFontSize) ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
                    ])
                    result.replaceCharacters(in: match.range, with: replacement)
                }
            }
        }
        
        // Code: `text`
        let codePattern = "`([^`]+)`"
        if let codeRegex = try? NSRegularExpression(pattern: codePattern) {
            let matches = codeRegex.matches(in: result.string, range: NSRange(location: 0, length: result.length)).reversed()
            for match in matches {
                if match.numberOfRanges >= 2 {
                    let contentRange = match.range(at: 1)
                    let content = (result.string as NSString).substring(with: contentRange)
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
                // Check for headers (large bold text)
                if font.pointSize >= 20 && font.fontDescriptor.symbolicTraits.contains(.bold) {
                    if font.pointSize >= 24 {
                        markdown += "# \(substring)"
                    } else {
                        markdown += "## \(substring)"
                    }
                }
                // Bold
                else if font.fontDescriptor.symbolicTraits.contains(.bold) {
                    markdown += "**\(substring)**"
                }
                // Italic
                else if font.fontDescriptor.symbolicTraits.contains(.italic) {
                    markdown += "*\(substring)*"
                }
                // Monospace (code)
                else if font.familyName?.contains("Mono") == true || font.familyName?.contains("Courier") == true {
                    markdown += "`\(substring)`"
                }
                // Regular text
                else {
                    markdown += substring
                }
            } else {
                markdown += substring
            }
        }
        
        return markdown
    }
    // MARK: - Markdown to HTML (Enhanced)

    static func markdownToHTML(_ markdown: String) -> String {
        var html = ""
        let lines = markdown.components(separatedBy: .newlines)
        var i = 0
        var inParagraph = false
        var inList = false

        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)

            // Empty lines close open blocks
            if trimmed.isEmpty {
                if inParagraph { html += "</p>\n"; inParagraph = false }
                if inList { html += "</ul>\n"; inList = false }
                i += 1; continue
            }

            // Table: collect all consecutive pipe-prefixed lines
            if trimmed.hasPrefix("|") {
                if inParagraph { html += "</p>\n"; inParagraph = false }
                if inList { html += "</ul>\n"; inList = false }
                var tableLines: [String] = []
                while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    tableLines.append(lines[i].trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                html += renderMarkdownTable(tableLines)
                continue
            }

            // Horizontal Rule
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                if inParagraph { html += "</p>\n"; inParagraph = false }
                if inList { html += "</ul>\n"; inList = false }
                html += "<hr />\n"
                i += 1; continue
            }

            // Headers
            if trimmed.hasPrefix("#") {
                if inParagraph { html += "</p>\n"; inParagraph = false }
                if inList { html += "</ul>\n"; inList = false }
                let level = trimmed.prefix(while: { $0 == "#" }).count
                let content = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                let slug = content.lowercased()
                    .components(separatedBy: .whitespacesAndNewlines)
                    .joined(separator: "-")
                    .filter { $0.isLetter || $0.isNumber || $0 == "-" }
                html += "<h\(level) id=\"\(slug)\">\(parseInline(content))</h\(level)>\n"
                i += 1; continue
            }

            // Blockquotes
            if trimmed.hasPrefix(">") {
                if inParagraph { html += "</p>\n"; inParagraph = false }
                if inList { html += "</ul>\n"; inList = false }
                let content = trimmed.hasPrefix("> ") ? String(trimmed.dropFirst(2)) : String(trimmed.dropFirst(1))
                html += "<blockquote>\n<p>\(parseInline(content))</p>\n</blockquote>\n"
                i += 1; continue
            }

            // List items
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                if inParagraph { html += "</p>\n"; inParagraph = false }
                if !inList { html += "<ul>\n"; inList = true }
                html += "<li>\(parseInline(String(trimmed.dropFirst(2))))</li>\n"
                i += 1; continue
            }

            // Paragraphs
            if inList { html += "</ul>\n"; inList = false }
            if !inParagraph { html += "<p>"; inParagraph = true } else { html += " " }
            html += parseInline(trimmed)
            i += 1
        }

        if inParagraph { html += "</p>" }
        if inList { html += "</ul>" }

        return html.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Renders a block of | -prefixed lines as an HTML table.
    // First non-separator row(s) → <thead>, separator row (---|---) marks the split, rest → <tbody>.
    private static func renderMarkdownTable(_ lines: [String]) -> String {
        var headerLines: [String] = []
        var bodyLines: [String] = []
        var separatorFound = false

        for line in lines {
            let cells = parseTableRow(line)
            // Separator: every cell is only dashes and colons (e.g. "---", ":---:", "---:")
            let isSeparator = !cells.isEmpty && cells.allSatisfy { cell in
                !cell.isEmpty && cell.allSatisfy { $0 == "-" || $0 == ":" }
            }
            if isSeparator {
                separatorFound = true
            } else if separatorFound {
                bodyLines.append(line)
            } else {
                headerLines.append(line)
            }
        }

        // No separator → treat everything as body rows
        if !separatorFound { bodyLines = headerLines; headerLines = [] }

        var html = "<table>\n"

        if !headerLines.isEmpty {
            html += "<thead>\n"
            for line in headerLines {
                let cells = parseTableRow(line)
                html += "<tr>" + cells.map { "<th>\(parseInline($0))</th>" }.joined() + "</tr>\n"
            }
            html += "</thead>\n"
        }

        if !bodyLines.isEmpty {
            html += "<tbody>\n"
            for line in bodyLines {
                let cells = parseTableRow(line)
                guard !cells.isEmpty else { continue }
                html += "<tr>" + cells.map { "<td>\(parseInline($0))</td>" }.joined() + "</tr>\n"
            }
            html += "</tbody>\n"
        }

        html += "</table>\n"
        return html
    }

    private static func parseTableRow(_ line: String) -> [String] {
        line.trimmingCharacters(in: .whitespaces)
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    
    // MARK: - HTML to Markdown (Custom)
    
    static func htmlToMarkdown(_ html: String) -> String {
        var markdown = html
        
        // 1. Remove system-generated newlines to process as a stream
        markdown = markdown.replacingOccurrences(of: "\n", with: " ")
        
        // 2. Headers
        markdown = markdown.replacingOccurrences(of: "<h1[^>]*>(.*?)</h1>", with: "\n# $1\n", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<h2[^>]*>(.*?)</h2>", with: "\n## $1\n", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<h3[^>]*>(.*?)</h3>", with: "\n### $1\n", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<h4[^>]*>(.*?)</h4>", with: "\n#### $1\n", options: .regularExpression)
        
        // 3. Lists
        markdown = markdown.replacingOccurrences(of: "<ul>", with: "\n")
        markdown = markdown.replacingOccurrences(of: "</ul>", with: "\n")
        markdown = markdown.replacingOccurrences(of: "<li>(.*?)</li>", with: "\n- $1", options: .regularExpression)
        
        // 4. Formatting
        markdown = markdown.replacingOccurrences(of: "<strong>(.*?)</strong>", with: "**$1**", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<b>(.*?)</b>", with: "**$1**", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<em>(.*?)</em>", with: "_$1_", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<i>(.*?)</i>", with: "_$1_", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<code>(.*?)</code>", with: "`$1`", options: .regularExpression)
        
        // 5. Block elements
        markdown = markdown.replacingOccurrences(of: "<p>(.*?)</p>", with: "\n$1\n", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<hr\\s*/?>", with: "\n---\n", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<blockquote>(.*?)</blockquote>", with: "\n> $1\n", options: .regularExpression)
        
        // 6. Links
        markdown = markdown.replacingOccurrences(of: "<a href=\"(.*?)\"[^>]*>(.*?)</a>", with: "[$2]($1)", options: .regularExpression)
        
        // 7. Clean up
        // Decode entities (basic)
        markdown = markdown.replacingOccurrences(of: "&lt;", with: "<")
        markdown = markdown.replacingOccurrences(of: "&gt;", with: ">")
        markdown = markdown.replacingOccurrences(of: "&amp;", with: "&")
        markdown = markdown.replacingOccurrences(of: "&quot;", with: "\"")
        markdown = markdown.replacingOccurrences(of: "&nbsp;", with: " ")
        
        // Fix multiple newlines
        while markdown.contains("\n\n\n") {
            markdown = markdown.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        
        return markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func parseInline(_ text: String) -> String {
        var result = text

        // Links ([text](url)) — must be before bold/italic to avoid mangling URLs
        result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\(([^)]+)\\)", with: "<a href=\"$2\" target=\"_blank\">$1</a>", options: .regularExpression)

        // Bold (**text**) — allow any content inside including already-parsed HTML
        result = result.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)

        // Italic (*text* or _text_) — non-greedy, avoid matching inside URLs/HTML
        result = result.replacingOccurrences(of: "(?<![\\w*])\\*([^*]+?)\\*(?![\\w*])", with: "<em>$1</em>", options: .regularExpression)
        result = result.replacingOccurrences(of: "(?<![\\w_])_([^_]+?)_(?![\\w_])", with: "<em>$1</em>", options: .regularExpression)

        // Code (`text`)
        result = result.replacingOccurrences(of: "`([^`]+)`", with: "<code>$1</code>", options: .regularExpression)

        return result
    }
}
