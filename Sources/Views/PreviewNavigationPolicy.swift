import WebKit
import AppKit

// Shared navigation policy for the markdown-preview WebViews. Their content is
// untrusted (opened files, pasted text), so the WebView must never navigate
// in-place: an http(s) link in a malicious markdown file would otherwise turn
// the preview into an in-app phishing surface. Link clicks open the default
// browser; everything except the initial loadHTMLString is cancelled.
enum PreviewNavigationPolicy {
    static func decide(_ action: WKNavigationAction) -> WKNavigationActionPolicy {
        // loadHTMLString(baseURL: nil) and internal anchors arrive as about:blank.
        guard let url = action.request.url, url.scheme != "about" else { return .allow }
        if action.navigationType == .linkActivated,
           ["http", "https", "mailto"].contains(url.scheme ?? "") {
            NSWorkspace.shared.open(url)
        }
        return .cancel
    }
}
