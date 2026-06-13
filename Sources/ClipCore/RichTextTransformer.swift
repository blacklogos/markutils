import Foundation

// Pure-Foundation transformer: markdownToHTML, htmlToMarkdown, and related helpers.
// The AppKit-dependent markdownToRichText lives in
// Sources/Utilities/RichTextTransformer.swift as an extension in the Clip app target.
public struct RichTextTransformer {

    // MARK: - Markdown to HTML

    public static func markdownToHTML(_ markdown: String) -> String {
        var html = ""
        var lines = markdown.components(separatedBy: .newlines)
        var i = 0
        var inParagraph = false
        var inList = false
        var inOrderedList = false
        // Offset from current line index back to the ORIGINAL document line.
        // Task checkboxes carry data-line="<original index>" so interactive
        // previews can toggle the exact source line without re-counting.
        var lineOffset = 0

        // YAML frontmatter renders as a muted metadata block instead of
        // leaking into the document as stray paragraphs and rules.
        if let frontmatter = extractFrontmatter(lines) {
            html += "<pre class=\"frontmatter\"><code>"
                + frontmatter.block.map(htmlEscape).joined(separator: "\n")
                + "</code></pre>\n"
            lineOffset = lines.count - frontmatter.rest.count
            lines = frontmatter.rest
        }

        func closeBlocks() {
            if inParagraph { html += "</p>\n"; inParagraph = false }
            if inList { html += "</ul>\n"; inList = false }
            if inOrderedList { html += "</ol>\n"; inOrderedList = false }
        }

        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)

            // Fenced code blocks — checked before empty-line handling because
            // fences may contain blank lines that must not close the block.
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                closeBlocks()
                let fence = trimmed.hasPrefix("```") ? "```" : "~~~"
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
                    codeLines.append(lines[i])
                    i += 1
                }
                i += 1 // skip the closing fence (or run past an unterminated one)
                html += "<pre><code>" + codeLines.map(htmlEscape).joined(separator: "\n") + "</code></pre>\n"
                continue
            }

            // Empty lines close open blocks
            if trimmed.isEmpty {
                closeBlocks()
                i += 1; continue
            }

            // Table: collect all consecutive pipe-prefixed lines
            if trimmed.hasPrefix("|") {
                closeBlocks()
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
                closeBlocks()
                html += "<hr />\n"
                i += 1; continue
            }

            // Headers
            if trimmed.hasPrefix("#") {
                closeBlocks()
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
                closeBlocks()
                let content = trimmed.hasPrefix("> ") ? String(trimmed.dropFirst(2)) : String(trimmed.dropFirst(1))
                html += "<blockquote>\n<p>\(parseInline(content))</p>\n</blockquote>\n"
                i += 1; continue
            }

            // Unordered list items (including GitHub-style task checkboxes)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                if inParagraph { html += "</p>\n"; inParagraph = false }
                if inOrderedList { html += "</ol>\n"; inOrderedList = false }
                if !inList { html += "<ul>\n"; inList = true }
                let item = String(trimmed.dropFirst(2))
                if item.hasPrefix("[ ] ") || item.hasPrefix("[x] ") || item.hasPrefix("[X] ") {
                    let checked = !item.hasPrefix("[ ] ")
                    let content = String(item.dropFirst(4))
                    html += "<li class=\"task\"><input type=\"checkbox\" disabled data-line=\"\(i + lineOffset)\"\(checked ? " checked" : "")> \(parseInline(content))</li>\n"
                } else {
                    html += "<li>\(parseInline(item))</li>\n"
                }
                i += 1; continue
            }

            // Ordered list items ("1. " or "1) "). Per CommonMark, only a list
            // starting at 1 may interrupt a paragraph — keeps hard-wrapped prose
            // like "…extension\n5) press star" from being misparsed as a list.
            if let marker = trimmed.range(of: #"^\d{1,3}[.)] "#, options: .regularExpression),
               !inParagraph || inOrderedList || trimmed.hasPrefix("1.") || trimmed.hasPrefix("1)") {
                if inParagraph { html += "</p>\n"; inParagraph = false }
                if inList { html += "</ul>\n"; inList = false }
                if !inOrderedList { html += "<ol>\n"; inOrderedList = true }
                html += "<li>\(parseInline(String(trimmed[marker.upperBound...])))</li>\n"
                i += 1; continue
            }

            // Paragraphs
            if inList { html += "</ul>\n"; inList = false }
            if inOrderedList { html += "</ol>\n"; inOrderedList = false }
            if !inParagraph { html += "<p>"; inParagraph = true } else { html += " " }
            html += parseInline(trimmed)
            i += 1
        }

        if inParagraph { html += "</p>" }
        if inList { html += "</ul>" }
        if inOrderedList { html += "</ol>" }

        return html.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Detects a YAML frontmatter block: an opening `---` on the first line and
    /// a closing `---` within the first 50 lines. To avoid swallowing documents
    /// that merely start with a horizontal rule, EVERY non-empty line between
    /// the fences must look like YAML (`key: value`, a `- ` list entry, an
    /// indented continuation, or a `#` comment) and at least one must be a key.
    /// Returns the inner lines and the remaining document, or nil if absent.
    public static func extractFrontmatter(_ lines: [String]) -> (block: [String], rest: [String])? {
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }
        guard let closeIndex = lines.dropFirst().prefix(50).firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "---"
        }) else { return nil }

        let block = Array(lines[1..<closeIndex])
        let isKeyLine = { (line: String) in
            line.range(of: #"^\s*[\w-]+\s*:"#, options: .regularExpression) != nil
        }
        // NOTE: no "#"-comment allowance — markdown headings also start with #,
        // and a heading between two rules means prose, not metadata.
        let isYAMLish = { (line: String) in
            isKeyLine(line)
                || line.range(of: #"^\s*-\s"#, options: .regularExpression) != nil
                || line.hasPrefix(" ") || line.hasPrefix("\t")
        }
        let nonEmpty = block.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !nonEmpty.isEmpty,
              nonEmpty.contains(where: isKeyLine),
              nonEmpty.allSatisfy(isYAMLish) else { return nil }

        return (block, Array(lines[(closeIndex + 1)...]))
    }

    // Renders a block of | -prefixed lines as an HTML table.
    // First non-separator row(s) → <thead>, separator row (---|---) marks the split, rest → <tbody>.
    static func renderMarkdownTable(_ lines: [String]) -> String {
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

    static func parseTableRow(_ line: String) -> [String] {
        line.trimmingCharacters(in: .whitespaces)
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - HTML to Markdown

    public static func htmlToMarkdown(_ html: String) -> String {
        var markdown = html

        // 0. Extract <pre> blocks into placeholders BEFORE newline-flattening
        // so multi-line code (and frontmatter) survive the stream processing.
        var preBlocks: [String] = []
        if let preRegex = try? NSRegularExpression(
            pattern: "<pre( class=\"frontmatter\")?>\\s*<code[^>]*>(.*?)</code>\\s*</pre>",
            options: [.dotMatchesLineSeparators]
        ) {
            let ns = markdown as NSString
            var rebuilt = ""
            var cursor = 0
            for match in preRegex.matches(in: markdown, range: NSRange(location: 0, length: ns.length)) {
                rebuilt += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                let fence = match.range(at: 1).location != NSNotFound ? "---" : "```"
                let content = decodeHTMLEntities(ns.substring(with: match.range(at: 2)))
                preBlocks.append("\n\(fence)\n\(content)\n\(fence)\n")
                rebuilt += "\u{F8FF}PRE\(preBlocks.count - 1)\u{F8FF}"
                cursor = match.range.location + match.range.length
            }
            rebuilt += ns.substring(from: cursor)
            markdown = rebuilt
        }

        // 1. Remove system-generated newlines to process as a stream
        markdown = markdown.replacingOccurrences(of: "\n", with: " ")

        // 2. Tables — convert before stripping other tags
        markdown = convertHTMLTablesToMarkdown(markdown)

        // 3. Headers
        markdown = markdown.replacingOccurrences(of: "<h1[^>]*>(.*?)</h1>", with: "\n# $1\n", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<h2[^>]*>(.*?)</h2>", with: "\n## $1\n", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<h3[^>]*>(.*?)</h3>", with: "\n### $1\n", options: .regularExpression)
        markdown = markdown.replacingOccurrences(of: "<h4[^>]*>(.*?)</h4>", with: "\n#### $1\n", options: .regularExpression)

        // 4. Lists — task items first (checkbox state → markdown), then ordered
        // lists ("1." for every item; markdown renumbers automatically), then
        // plain bullets. <li> may carry attributes (class="task", data-line).
        markdown = markdown.replacingOccurrences(
            of: "<li[^>]*><input[^>]*\\bchecked[^>]*> ?(.*?)</li>",
            with: "\n- [x] $1", options: .regularExpression)
        markdown = markdown.replacingOccurrences(
            of: "<li[^>]*><input[^>]*type=\"checkbox\"[^>]*> ?(.*?)</li>",
            with: "\n- [ ] $1", options: .regularExpression)
        if let olRegex = try? NSRegularExpression(pattern: "<ol>(.*?)</ol>", options: [.dotMatchesLineSeparators]) {
            let ns = markdown as NSString
            var rebuilt = ""
            var cursor = 0
            for match in olRegex.matches(in: markdown, range: NSRange(location: 0, length: ns.length)) {
                rebuilt += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
                rebuilt += "\n" + ns.substring(with: match.range(at: 1))
                    .replacingOccurrences(of: "<li[^>]*>(.*?)</li>", with: "\n1. $1", options: .regularExpression) + "\n"
                cursor = match.range.location + match.range.length
            }
            rebuilt += ns.substring(from: cursor)
            markdown = rebuilt
        }
        markdown = markdown.replacingOccurrences(of: "<ul>", with: "\n")
        markdown = markdown.replacingOccurrences(of: "</ul>", with: "\n")
        markdown = markdown.replacingOccurrences(of: "<li[^>]*>(.*?)</li>", with: "\n- $1", options: .regularExpression)

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
        markdown = decodeHTMLEntities(markdown)

        // 10. Restore protected <pre> blocks (content already decoded)
        for (index, block) in preBlocks.enumerated() {
            markdown = markdown.replacingOccurrences(of: "\u{F8FF}PRE\(index)\u{F8FF}", with: block)
        }

        // Fix multiple newlines
        while markdown.contains("\n\n\n") {
            markdown = markdown.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        return markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeHTMLEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#x27;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
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
        // Escape raw text first to prevent XSS via <script>, <img onerror=>, etc.
        var result = htmlEscape(text)

        // Links ([text](url)) — must be before bold/italic to avoid mangling URLs
        result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\(([^)]+)\\)", with: "<a href=\"$2\" target=\"_blank\">$1</a>", options: .regularExpression)
        // Strip non-http/mailto hrefs to prevent javascript: URI injection
        result = result.replacingOccurrences(of: " href=\"(?!https?://|mailto:)[^\"]*\"", with: " href=\"#\"", options: .regularExpression)

        // Bold (**text**) — allow any content inside including already-parsed HTML
        result = result.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)

        // Italic (*text* or _text_) — non-greedy, avoid matching inside URLs/HTML
        result = result.replacingOccurrences(of: "(?<![\\w*])\\*([^*]+?)\\*(?![\\w*])", with: "<em>$1</em>", options: .regularExpression)
        result = result.replacingOccurrences(of: "(?<![\\w_])_([^_]+?)_(?![\\w_])", with: "<em>$1</em>", options: .regularExpression)

        // Code (`text`)
        result = result.replacingOccurrences(of: "`([^`]+)`", with: "<code>$1</code>", options: .regularExpression)

        return result
    }

    // Escapes the five HTML-sensitive characters so user content cannot inject tags.
    static func htmlEscape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#x27;")
    }
}
