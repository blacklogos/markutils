import Foundation

// Pure-Foundation transformer: markdownToHTML, htmlToMarkdown, and related helpers.
// AppKit-dependent methods (markdownToRichText, richTextToMarkdown) live in
// Sources/Utilities/RichTextTransformer.swift as an extension in the Clip app target.
public struct RichTextTransformer {

    // MARK: - Markdown to HTML

    public static func markdownToHTML(_ markdown: String) -> String {
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
    public static func renderMarkdownTable(_ lines: [String]) -> String {
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

    public static func parseTableRow(_ line: String) -> [String] {
        line.trimmingCharacters(in: .whitespaces)
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - HTML to Markdown

    public static func htmlToMarkdown(_ html: String) -> String {
        var markdown = html

        // 1. Remove system-generated newlines to process as a stream
        markdown = markdown.replacingOccurrences(of: "\n", with: " ")

        // 2. Tables — convert before stripping other tags
        markdown = convertHTMLTablesToMarkdown(markdown)

        // 3. Headers
        markdown = markdown.replacingOccurrences(of: "<h1[^>]*>(.*?)</h1>", with: "\n# $1\n", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<h2[^>]*>(.*?)</h2>", with: "\n## $1\n", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<h3[^>]*>(.*?)</h3>", with: "\n### $1\n", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<h4[^>]*>(.*?)</h4>", with: "\n#### $1\n", options: .regularExpression)

        // 4. Lists
        markdown = markdown.replacingOccurrences(of: "<ul>", with: "\n")
        markdown = markdown.replacingOccurrences(of: "</ul>", with: "\n")
        markdown = markdown.replacingOccurrences(of: "<li>(.*?)</li>", with: "\n- $1", options: .regularExpression)

        // 5. Formatting
        markdown = markdown.replacingOccurrences(of: "<strong>(.*?)</strong>", with: "**$1**", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<b>(.*?)</b>", with: "**$1**", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<em>(.*?)</em>", with: "_$1_", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<i>(.*?)</i>", with: "_$1_", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<code>(.*?)</code>", with: "`$1`", options: .regularExpression)

        // 6. Block elements
        markdown = markdown.replacingOccurrences(of: "<p>(.*?)</p>", with: "\n$1\n", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<hr\\s*/?>", with: "\n---\n", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<blockquote>(.*?)</blockquote>", with: "\n> $1\n", options: .regularExpression)

        // 7. Links
        markdown = markdown.replacingOccurrences(of: "<a href=\"(.*?)\"[^>]*>(.*?)</a>", with: "[$2]($1)", options: .regularExpression)

        // 8. Strip any remaining tags
        markdown = markdown.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // 9. Decode entities (basic)
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

    // Converts <table>...</table> blocks in an HTML string to markdown tables.
    // Falls back to stripping tags if the table structure is malformed.
    private static func convertHTMLTablesToMarkdown(_ html: String) -> String {
        guard let tableRegex = try? NSRegularExpression(pattern: "<table[^>]*>(.*?)</table>",
                                                        options: [.dotMatchesLineSeparators]) else { return html }
        let nsHTML = html as NSString
        let matches = tableRegex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length)).reversed()
        var result = html
        for match in matches {
            let tableHTML = nsHTML.substring(with: match.range)
            let replacement = parseHTMLTable(tableHTML)
            result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
        }
        return result
    }

    // Parses a single <table>…</table> HTML snippet and produces a markdown table string.
    private static func parseHTMLTable(_ tableHTML: String) -> String {
        // Extract cells from <th> and <td> tags; track row boundaries via <tr>
        // Strategy: split on <tr> blocks, then extract th/td cells from each block
        guard let trRegex = try? NSRegularExpression(pattern: "<tr[^>]*>(.*?)</tr>",
                                                     options: [.dotMatchesLineSeparators]),
              let cellRegex = try? NSRegularExpression(pattern: "<t[hd][^>]*>(.*?)</t[hd]>",
                                                       options: [.dotMatchesLineSeparators]),
              let thRegex = try? NSRegularExpression(pattern: "<th[^>]*>", options: []) else {
            // Fallback: strip tags
            return tableHTML.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }

        let nsTable = tableHTML as NSString
        let trMatches = trRegex.matches(in: tableHTML, range: NSRange(location: 0, length: nsTable.length))

        // Determine if a row is a header row (contains <th> tags or is inside <thead>)
        var headerRows: [[String]] = []
        var bodyRows: [[String]] = []

        // Split html at thead/tbody boundaries to track which section rows belong to
        let inThead: (NSRange) -> Bool = { range in
            let before = nsTable.substring(to: range.location)
            let theadOpen = before.components(separatedBy: "<thead").count - 1
            let theadClose = before.components(separatedBy: "</thead").count - 1
            return theadOpen > theadClose
        }

        for trMatch in trMatches {
            let rowHTML = nsTable.substring(with: trMatch.range(at: 1))
            let nsRow = rowHTML as NSString
            let cellMatches = cellRegex.matches(in: rowHTML, range: NSRange(location: 0, length: nsRow.length))
            let cells = cellMatches.map { m -> String in
                let inner = nsRow.substring(with: m.range(at: 1))
                // Strip inner tags
                return inner.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard !cells.isEmpty else { continue }

            // Row is header if it lives inside <thead> or contains any <th>
            let hasThInRow = thRegex.firstMatch(in: rowHTML, range: NSRange(location: 0, length: nsRow.length)) != nil
            if inThead(trMatch.range) || hasThInRow {
                headerRows.append(cells)
            } else {
                bodyRows.append(cells)
            }
        }

        // Build markdown table
        guard !headerRows.isEmpty || !bodyRows.isEmpty else {
            return tableHTML.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }

        let colCount = (headerRows + bodyRows).map(\.count).max() ?? 0
        guard colCount > 0 else { return "" }

        func padRow(_ row: [String]) -> [String] {
            var r = row; while r.count < colCount { r.append("") }; return r
        }

        var lines: [String] = []

        // If no explicit header rows, use first body row as header
        let usedHeaders: [[String]]
        let usedBody: [[String]]
        if headerRows.isEmpty {
            usedHeaders = [bodyRows[0]]
            usedBody = Array(bodyRows.dropFirst())
        } else {
            usedHeaders = headerRows
            usedBody = bodyRows
        }

        for row in usedHeaders {
            lines.append("| " + padRow(row).joined(separator: " | ") + " |")
        }
        lines.append("| " + Array(repeating: "---", count: colCount).joined(separator: " | ") + " |")
        for row in usedBody {
            lines.append("| " + padRow(row).joined(separator: " | ") + " |")
        }

        return "\n" + lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Inline parsing (shared by markdownToHTML helpers)

    public static func parseInline(_ text: String) -> String {
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
