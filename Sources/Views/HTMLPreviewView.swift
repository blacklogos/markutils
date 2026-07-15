import SwiftUI
import WebKit

struct HTMLPreviewView: NSViewRepresentable {
    let htmlContent: String

    private var fullHTML: String {
        MarkdownPreviewStyle.page(body: htmlContent)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Skip identical reloads — unrelated SwiftUI state changes would
        // otherwise reset the scroll position on every body evaluation.
        let html = fullHTML
        guard html != context.coordinator.lastHTML else { return }
        context.coordinator.lastHTML = html
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var lastHTML = ""
    }
}
