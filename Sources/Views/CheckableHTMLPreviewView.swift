import SwiftUI
import WebKit

// WKWebView-based markdown preview that renders - [ ] / - [x] as clickable checkboxes.
// onToggle receives the sequential checkbox index and its new checked state.
// Create separately from HTMLPreviewView to avoid touching shared Transform tab code.
struct CheckableHTMLPreviewView: NSViewRepresentable {
    let html: String
    let onToggle: (Int, Bool) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "checkbox")

        // Inject JS at document end to wire up checkbox change events
        let js = """
        document.querySelectorAll('input[type=checkbox]').forEach(function(cb) {
            cb.addEventListener('change', function() {
                window.webkit.messageHandlers.checkbox.postMessage(
                    {idx: parseInt(this.dataset.idx), checked: this.checked}
                );
            });
        });
        """
        let script = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        controller.addUserScript(script)

        let config = WKWebViewConfiguration()
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(fullHTML(for: html), baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onToggle: onToggle)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var onToggle: (Int, Bool) -> Void

        init(onToggle: @escaping (Int, Bool) -> Void) {
            self.onToggle = onToggle
        }

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let idx = body["idx"] as? Int,
                  let checked = body["checked"] as? Bool
            else { return }
            DispatchQueue.main.async { self.onToggle(idx, checked) }
        }
    }

    // MARK: - HTML generation

    // Replaces <li>[ ] and <li>[x] patterns with <input type=checkbox> elements,
    // assigning sequential data-idx for mapping back to the markdown source.
    private func processedHTML(_ raw: String) -> String {
        let pattern = #"<li>\[([ xX])\] "#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return raw }
        let matches = regex.matches(in: raw, range: NSRange(raw.startIndex..., in: raw))
        let nsResult = NSMutableString(string: raw)
        var offset = 0
        for (idx, match) in matches.enumerated() {
            let charRange = NSRange(location: match.range(at: 1).location + offset,
                                   length: match.range(at: 1).length)
            // Read from nsResult (already offset) to get the check character
            let checkChar = nsResult.substring(with: charRange).lowercased()
            let isChecked = checkChar == "x"
            let replacement = isChecked
                ? "<li><input type=\"checkbox\" checked data-idx=\"\(idx)\"> "
                : "<li><input type=\"checkbox\" data-idx=\"\(idx)\"> "
            let targetRange = NSRange(location: match.range.location + offset, length: match.range.length)
            nsResult.replaceCharacters(in: targetRange, with: replacement)
            offset += (replacement as NSString).length - match.range.length
        }
        return nsResult as String
    }

    private func fullHTML(for content: String) -> String {
        let body = processedHTML(content)
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
            :root {
                color-scheme: light dark;
                --bg: #F7F4EF; --fg: #2C2C2C; --fg2: #8A8078;
                --accent: #C47D4E; --border: rgba(160,140,120,0.2);
                --code-bg: rgba(160,140,120,0.12); --th-bg: rgba(160,140,120,0.1);
            }
            @media (prefers-color-scheme: dark) {
                :root { --bg: #252525; --fg: #E8E0D8; --accent: #D4956A;
                    --border: rgba(160,140,120,0.18); --code-bg: rgba(160,140,120,0.1); }
            }
            body { font-family: Georgia, serif; font-size: 14px; line-height: 1.7;
                   padding: 14px 18px; margin: 0; color: var(--fg); background: var(--bg); }
            h1,h2,h3 { font-family: -apple-system, sans-serif; font-weight: 600; color: var(--fg); }
            h1 { font-size: 1.75em; border-bottom: 1px solid var(--border); padding-bottom: 0.3em; }
            h2 { font-size: 1.35em; border-bottom: 1px solid var(--border); padding-bottom: 0.2em; }
            ul, ol { padding-left: 1.5em; margin: 0.4em 0; }
            li { margin: 0.2em 0; }
            input[type=checkbox] { cursor: pointer; accent-color: var(--accent); }
            code { font-family: "SF Mono", Menlo, monospace; font-size: 0.88em;
                   padding: 0.15em 0.4em; border-radius: 3px; background: var(--code-bg); }
            table { border-collapse: collapse; width: 100%; margin: 0.6em 0; }
            th,td { border: 1px solid var(--border); padding: 6px 12px; text-align: left; }
            th { background: var(--th-bg); font-weight: 600; }
        </style>
        </head>
        <body>\(body)</body>
        </html>
        """
    }
}
