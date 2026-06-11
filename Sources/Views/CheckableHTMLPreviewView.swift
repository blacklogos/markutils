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
        MarkdownPreviewStyle.page(body: processedHTML(content))
    }
}
