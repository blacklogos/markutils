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
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Skip identical reloads — unrelated SwiftUI state changes would
        // otherwise reset the scroll position on every body evaluation.
        let html = fullHTML
        guard html != context.coordinator.lastHTML else { return }
        let isFirstLoad = context.coordinator.lastHTML.isEmpty
        context.coordinator.lastHTML = html

        if isFirstLoad {
            webView.loadHTMLString(html, baseURL: nil)
        } else {
            // Capture scroll before the reload; restored in didFinish. Without
            // this, every content change jumps the preview back to the top.
            webView.evaluateJavaScript("window.scrollY") { y, _ in
                context.coordinator.pendingScrollY = y as? Double ?? 0
                webView.loadHTMLString(html, baseURL: nil)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastHTML = ""
        var pendingScrollY: Double = 0

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard pendingScrollY > 0 else { return }
            // Instant (non-smooth) restore so the reload is invisible.
            webView.evaluateJavaScript("window.scrollTo(0, \(pendingScrollY))")
            pendingScrollY = 0
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(PreviewNavigationPolicy.decide(navigationAction))
        }
    }
}
