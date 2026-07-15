import Foundation
import ClipCore

/// Renders a side-by-side (split) diff into HTML for the Diff tab's WebView:
/// per-pane headers (removal/addition counts, line totals, Copy), line numbers,
/// paired rows with hatched fillers, and intra-line `.seg` highlights.
/// Every piece of pane text is HTML-escaped — the panes hold untrusted pasted text.
enum DiffHTMLRenderer {

    /// Returns a body fragment — HTMLPreviewView wraps it in the page envelope.
    static func html(for lines: [TextDiff.AnnotatedLine], original: String, revised: String) -> String {
        guard !lines.isEmpty else {
            return "<div class=\"diff-empty\">Paste text into both panes to compare.</div>"
        }

        let removals = lines.filter { $0.kind == .removed }.count
        let additions = lines.filter { $0.kind == .added }.count
        let rows = TextDiff.sideBySideRows(lines).map(rowHTML(for:)).joined(separator: "\n")

        var body = header(removals: removals, additions: additions,
                          originalLines: lineCount(original), revisedLines: lineCount(revised))
        if removals == 0 && additions == 0 {
            body = "<div class=\"diff-empty\">No differences — the two texts are identical.</div>" + body
        }
        body += "<div class=\"split\">\(rows)</div>" + copyScript(original: original, revised: revised)
        return body
    }

    // MARK: - Header

    private static func header(removals: Int, additions: Int,
                               originalLines: Int, revisedLines: Int) -> String {
        """
        <div class="split-header">
          <div class="pane">
            <span class="count rem">&ominus; \(removals) removal\(removals == 1 ? "" : "s")</span>
            <span class="meta">\(originalLines) line\(originalLines == 1 ? "" : "s")</span>
            <button class="copy-btn" onclick="copyPane(0, this)">Copy</button>
          </div>
          <div class="pane">
            <span class="count add">&oplus; \(additions) addition\(additions == 1 ? "" : "s")</span>
            <span class="meta">\(revisedLines) line\(revisedLines == 1 ? "" : "s")</span>
            <button class="copy-btn" onclick="copyPane(1, this)">Copy</button>
          </div>
        </div>
        """
    }

    // MARK: - Rows

    private static func rowHTML(for row: TextDiff.SideRow) -> String {
        "<div class=\"split-row\">"
            + cellHTML(row.left, side: "left", changedClass: "removed")
            + cellHTML(row.right, side: "right", changedClass: "added")
            + "</div>"
    }

    private static func cellHTML(_ cell: TextDiff.SideCell?, side: String, changedClass: String) -> String {
        guard let cell else {
            return "<div class=\"cell \(side) filler\"><span class=\"lineno\">&nbsp;</span>"
                + "<span class=\"text\">&nbsp;</span></div>"
        }
        let cls = cell.changed ? " \(changedClass)" : ""
        return "<div class=\"cell \(side)\(cls)\"><span class=\"lineno\">\(cell.lineNumber)</span>"
            + "<span class=\"text\">\(textHTML(for: cell))</span></div>"
    }

    /// Whole line when no segments; otherwise changed runs wrapped in `.seg` spans.
    private static func textHTML(for cell: TextDiff.SideCell) -> String {
        guard let segments = cell.segments else {
            return cell.text.isEmpty ? "&nbsp;" : RichTextTransformer.htmlEscape(cell.text)
        }
        return segments.map { seg in
            let escaped = RichTextTransformer.htmlEscape(seg.text)
            return seg.changed ? "<span class=\"seg\">\(escaped)</span>" : escaped
        }.joined()
    }

    // MARK: - Copy support

    /// Embeds the two pane texts as JSON and copies via clipboard API with an
    /// execCommand fallback (WKWebView clipboard permissions vary by OS version).
    private static func copyScript(original: String, revised: String) -> String {
        """
        <script>
        const paneTexts = [\(jsString(original)), \(jsString(revised))];
        function copyPane(i, btn) {
          const t = paneTexts[i];
          const done = () => {
            const old = btn.textContent;
            btn.textContent = "Copied";
            setTimeout(() => { btn.textContent = old; }, 1200);
          };
          if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(t).then(done).catch(() => { fallbackCopy(t); done(); });
          } else { fallbackCopy(t); done(); }
        }
        function fallbackCopy(t) {
          const ta = document.createElement("textarea");
          ta.value = t;
          document.body.appendChild(ta);
          ta.select();
          document.execCommand("copy");
          ta.remove();
        }
        </script>
        """
    }

    /// JSON-encodes a Swift string as a JS string literal; "</" escaped so pasted
    /// "</script>" content cannot terminate the script element.
    private static func jsString(_ s: String) -> String {
        let data = (try? JSONEncoder().encode([s])) ?? Data("[\"\"]".utf8)
        let json = String(data: data, encoding: .utf8) ?? "[\"\"]"
        return String(json.dropFirst().dropLast()).replacingOccurrences(of: "</", with: "<\\/")
    }

    private static func lineCount(_ s: String) -> Int {
        s.isEmpty ? 0 : s.reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
    }
}
