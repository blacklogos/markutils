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
        var inParagraph = false
        var inList = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Empty lines close paragraphs and lists
            if trimmed.isEmpty {
                if inParagraph {
                    html += "</p>\n"
                    inParagraph = false
                }
                if inList {
                    html += "</ul>\n"
                    inList = false
                }
                continue
            }
            
            // Horizontal Rule
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                if inParagraph { html += "</p>\n"; inParagraph = false }
                if inList { html += "</ul>\n"; inList = false }
                html += "<hr />\n"
                continue
            }
            
            // Headers
            if trimmed.hasPrefix("#") {
                if inParagraph { html += "</p>\n"; inParagraph = false }
                if inList { html += "</ul>\n"; inList = false }
                
                let level = trimmed.prefix(while: { $0 == "#" }).count
                let content = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                let parsedContent = parseInline(content)
                let slug = content.lowercased()
                    .components(separatedBy: .whitespacesAndNewlines)
                    .joined(separator: "-")
                    .filter { $0.isLetter || $0.isNumber || $0 == "-" }
                
                html += "<h\(level) id=\"\(slug)\">\(parsedContent)</h\(level)>\n"
            }
            // Blockquotes
            else if trimmed.hasPrefix("> ") {
                if inParagraph { html += "</p>\n"; inParagraph = false }
                if inList { html += "</ul>\n"; inList = false }
                
                let content = String(trimmed.dropFirst(2))
                let parsedContent = parseInline(content)
                html += "<blockquote>\n<p>\(parsedContent)</p>\n</blockquote>\n"
            }
            // List items
            else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                if inParagraph { html += "</p>\n"; inParagraph = false }
                if !inList {
                    html += "<ul>\n"
                    inList = true
                }
                let content = String(trimmed.dropFirst(2))
                let parsedContent = parseInline(content)
                html += "<li>\(parsedContent)</li>\n"
            }
            // Paragraphs
            else {
                if inList { html += "</ul>\n"; inList = false }
                
                let parsedContent = parseInline(trimmed)
                
                if !inParagraph {
                    html += "<p>"
                    inParagraph = true
                } else {
                    html += " " // Join lines in same paragraph
                }
                html += parsedContent
            }
        }
        
        if inParagraph { html += "</p>" }
        if inList { html += "</ul>" }
        
        return html.trimmingCharacters(in: .whitespacesAndNewlines)
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
        
        // Bold (**text**)
        result = result.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        
        // Italic (*text* or _text_)
        result = result.replacingOccurrences(of: "\\*([^*]+)\\*", with: "<em>$1</em>", options: .regularExpression)
        result = result.replacingOccurrences(of: "_([^_]+)_", with: "<em>$1</em>", options: .regularExpression)
        
        // Code (`text`)
        result = result.replacingOccurrences(of: "`([^`]+)`", with: "<code>$1</code>", options: .regularExpression)
        
        // Links ([text](url))
        result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\(([^)]+)\\)", with: "<a href=\"$2\">$1</a>", options: .regularExpression)
        
        return result
    }
}
