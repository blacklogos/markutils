import SwiftUI
import WebKit

// WKWebView-based markdown preview that renders - [ ] / - [x] as clickable checkboxes.
// onToggle receives the markdown SOURCE LINE NUMBER (from the data-line attribute
// markdownToHTML emits on every task checkbox) and the new checked state, so the
// caller toggles the exact line — no fragile nth-checkbox counting.
// Create separately from HTMLPreviewView to avoid touching shared Transform tab code.
struct CheckableHTMLPreviewView: NSViewRepresentable {
    let html: String
    let onToggle: (Int, Bool) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "checkbox")

        // Inject JS at document end to wire up checkbox change events
        let js = """
        document.querySelectorAll('input[type=checkbox][data-line]').forEach(function(cb) {
            cb.addEventListener('change', function() {
                window.webkit.messageHandlers.checkbox.postMessage(
                    {line: parseInt(this.dataset.line), checked: this.checked}
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
        // Skip identical reloads — unrelated SwiftUI state changes would
        // otherwise reset the scroll position on every body evaluation.
        let full = fullHTML(for: html)
        guard full != context.coordinator.lastHTML else { return }
        context.coordinator.lastHTML = full
        webView.loadHTMLString(full, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onToggle: onToggle)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var onToggle: (Int, Bool) -> Void
        var lastHTML = ""

        init(onToggle: @escaping (Int, Bool) -> Void) {
            self.onToggle = onToggle
        }

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let line = body["line"] as? Int,
                  let checked = body["checked"] as? Bool
            else { return }
            DispatchQueue.main.async { self.onToggle(line, checked) }
        }
    }

    // MARK: - HTML generation

    // markdownToHTML emits task items as disabled checkboxes carrying their
    // source line in data-line. Re-enable them here; the data-line attribute
    // passes straight through to the toggle handler.
    private func processedHTML(_ raw: String) -> String {
        raw.replacingOccurrences(of: "<input type=\"checkbox\" disabled data-line=",
                                 with: "<input type=\"checkbox\" data-line=")
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
            li.task { list-style: none; margin-left: -1.3em; }
            li.task input[type=checkbox] { vertical-align: -2px; margin-right: 4px; }
            pre { padding: 12px; border-radius: 6px; background: var(--code-bg); overflow-x: auto; }
            pre code { padding: 0; background: none; }
            pre.frontmatter { font-size: 0.78em; color: var(--fg2); background: var(--th-bg);
                              border: 1px dashed var(--border); }
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
