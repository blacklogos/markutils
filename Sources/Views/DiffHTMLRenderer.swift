import ClipCore

/// Renders a unified line diff into HTML for the Diff tab's WebView preview,
/// reusing the shared `MarkdownPreviewStyle` page envelope (and its `.diff-*`
/// classes). Every line is HTML-escaped — the panes hold untrusted pasted text.
enum DiffHTMLRenderer {
    static func html(for lines: [TextDiff.Line]) -> String {
        guard !lines.isEmpty else {
            return MarkdownPreviewStyle.page(
                body: "<div class=\"diff-empty\">Paste text into both panes to compare.</div>")
        }

        let rows = lines.map(row(for:)).joined(separator: "\n")

        if lines.allSatisfy({ $0.kind == .equal }) {
            let banner = "<div class=\"diff-empty\">No differences — the two texts are identical.</div>"
            return MarkdownPreviewStyle.page(body: banner + "<div class=\"diff\">\(rows)</div>")
        }
        return MarkdownPreviewStyle.page(body: "<div class=\"diff\">\(rows)</div>")
    }

    private static func row(for line: TextDiff.Line) -> String {
        let cls: String, gutter: String
        switch line.kind {
        case .equal:   cls = "equal";   gutter = "&nbsp;"
        case .added:   cls = "added";   gutter = "+"
        case .removed: cls = "removed"; gutter = "-"
        }
        let text = line.text.isEmpty ? "&nbsp;" : RichTextTransformer.htmlEscape(line.text)
        return "<div class=\"diff-line \(cls)\"><span class=\"gutter\">\(gutter)</span>"
            + "<span class=\"text\">\(text)</span></div>"
    }
}
