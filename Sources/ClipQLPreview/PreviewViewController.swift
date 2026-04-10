import Cocoa
import Quartz
import WebKit

class PreviewViewController: NSViewController, QLPreviewingController {

    let webView = WKWebView()

    override func loadView() {
        self.view = webView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        do {
            let markdown = try String(contentsOf: url, encoding: .utf8)
            let bodyHTML = markdownToHTML(markdown)
            let fullHTML = """
            <!DOCTYPE html>
            <html>
            <head>
            <meta charset="utf-8">
            <style>
                :root {
                    color-scheme: light dark;
                    --bg: #FAFAFA;
                    --fg: #2C2C2C;
                    --fg2: #8A8078;
                    --accent: #C47D4E;
                    --border: rgba(160,140,120,0.2);
                    --code-bg: rgba(160,140,120,0.12);
                    --th-bg: rgba(160,140,120,0.1);
                }
                @media (prefers-color-scheme: dark) {
                    :root {
                        --bg: #1E1E1E;
                        --fg: #E8E0D8;
                        --fg2: #8A8078;
                        --accent: #D4956A;
                        --border: rgba(160,140,120,0.18);
                        --code-bg: rgba(160,140,120,0.1);
                        --th-bg: rgba(160,140,120,0.08);
                    }
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
                    font-size: 14px;
                    line-height: 1.7;
                    padding: 24px 32px;
                    margin: 0;
                    color: var(--fg);
                    background: var(--bg);
                }
                h1, h2, h3, h4 { font-weight: 600; color: var(--fg); }
                h1 { font-size: 1.75em; margin: 0.8em 0 0.4em; border-bottom: 1px solid var(--border); padding-bottom: 0.3em; }
                h2 { font-size: 1.35em; margin: 0.8em 0 0.4em; border-bottom: 1px solid var(--border); padding-bottom: 0.2em; }
                h3 { font-size: 1.1em; margin: 0.6em 0 0.3em; }
                p { margin: 0.5em 0; }
                ul, ol { padding-left: 1.5em; margin: 0.4em 0; }
                li { margin: 0.2em 0; }
                a { color: var(--accent); text-decoration: none; }
                code {
                    font-family: "SF Mono", Menlo, monospace;
                    font-size: 0.88em;
                    padding: 0.15em 0.4em;
                    border-radius: 3px;
                    background: var(--code-bg);
                }
                pre { padding: 12px; border-radius: 6px; background: var(--code-bg); overflow-x: auto; }
                pre code { padding: 0; background: none; }
                blockquote {
                    margin: 0.5em 0; padding: 0.3em 1em;
                    border-left: 3px solid var(--accent); color: var(--fg2);
                }
                hr { border: none; border-top: 1px solid var(--border); margin: 1em 0; }
                strong { font-weight: 700; }
                table { border-collapse: collapse; width: 100%; margin: 0.6em 0; font-size: 0.94em; }
                th, td { border: 1px solid var(--border); padding: 6px 12px; text-align: left; }
                th { background: var(--th-bg); font-weight: 600; }
                .clip-footer {
                    margin-top: 2em; padding-top: 0.8em;
                    border-top: 1px solid var(--border);
                    text-align: center; font-size: 0.75em; color: var(--fg2);
                }
            </style>
            </head>
            <body>\(bodyHTML)<div class="clip-footer">MD Preview by Clip</div></body>
            </html>
            """
            webView.loadHTMLString(fullHTML, baseURL: url.deletingLastPathComponent())
            handler(nil)
        } catch {
            handler(error)
        }
    }

    // MARK: - Inline Markdown → HTML (self-contained, no ClipCore dependency)

    private func markdownToHTML(_ markdown: String) -> String {
        var html = ""
        let lines = markdown.components(separatedBy: .newlines)
        var i = 0
        var inParagraph = false
        var inList = false

        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                if inParagraph { html += "</p>\n"; inParagraph = false }
                if inList { html += "</ul>\n"; inList = false }
                i += 1; continue
            }

            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                if inParagraph { html += "</p>\n"; inParagraph = false }
                if inList { html += "</ul>\n"; inList = false }
                html += "<hr />\n"; i += 1; continue
            }

            if trimmed.hasPrefix("#") {
                if inParagraph { html += "</p>\n"; inParagraph = false }
                if inList { html += "</ul>\n"; inList = false }
                let level = trimmed.prefix(while: { $0 == "#" }).count
                let content = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                html += "<h\(level)>\(parseInline(content))</h\(level)>\n"
                i += 1; continue
            }

            if trimmed.hasPrefix(">") {
                if inParagraph { html += "</p>\n"; inParagraph = false }
                if inList { html += "</ul>\n"; inList = false }
                let content = trimmed.hasPrefix("> ") ? String(trimmed.dropFirst(2)) : String(trimmed.dropFirst(1))
                html += "<blockquote><p>\(parseInline(content))</p></blockquote>\n"
                i += 1; continue
            }

            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                if inParagraph { html += "</p>\n"; inParagraph = false }
                if !inList { html += "<ul>\n"; inList = true }
                html += "<li>\(parseInline(String(trimmed.dropFirst(2))))</li>\n"
                i += 1; continue
            }

            if inList { html += "</ul>\n"; inList = false }
            if !inParagraph { html += "<p>"; inParagraph = true } else { html += " " }
            html += parseInline(trimmed)
            i += 1
        }

        if inParagraph { html += "</p>" }
        if inList { html += "</ul>" }
        return html.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseInline(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\(([^)]+)\\)", with: "<a href=\"$2\">$1</a>", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        result = result.replacingOccurrences(of: "(?<![\\w*])\\*([^*]+?)\\*(?![\\w*])", with: "<em>$1</em>", options: .regularExpression)
        result = result.replacingOccurrences(of: "`([^`]+)`", with: "<code>$1</code>", options: .regularExpression)
        return result
    }
}
