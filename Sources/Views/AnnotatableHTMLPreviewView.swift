import SwiftUI
import WebKit
import ClipCore

// WKWebView markdown preview that adds a commenting layer WITHOUT an editor and
// WITHOUT touching the ClipCore renderer:
//   • reports drag-selections (quote + surrounding context) over a validated
//     `selection` message handler, surfaced via a floating "Comment" button;
//   • wraps stored anchors' text in <mark class="clip-comment" data-id=…> and
//     posts `{id}` to `commentClicked` when one is clicked;
//   • exposes clipFlash(id) so the side panel can scroll to + flash an anchor.
//
// All text that crosses into the DOM is JSON-encoded (anchorsJSON) — the safe
// boundary — and every inbound message is shape-validated before use, because
// the bridge can reach native code (see XSS learning doc). Kept separate from
// HTMLPreviewView / CheckableHTMLPreviewView so the Transform tab is untouched.
struct AnnotatableHTMLPreviewView: NSViewRepresentable {
    let html: String
    let comments: [Comment]
    /// Set to an anchor id to scroll to + flash it; changing the value re-triggers.
    var flashAnchorID: UUID?
    let onSelect: (_ quote: String, _ prefix: String, _ suffix: String) -> Void
    let onCommentClicked: (UUID) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "selection")
        controller.add(context.coordinator, name: "commentClicked")

        let script = WKUserScript(source: Self.bridgeJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        controller.addUserScript(script)

        let config = WKWebViewConfiguration()
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        let full = MarkdownPreviewStyle.page(body: html)
        let anchors = Self.anchorsJSON(for: comments)

        if full != coordinator.lastHTML {
            // Content changed — reload, then re-apply highlights on didFinish.
            coordinator.lastHTML = full
            coordinator.pendingAnchors = anchors
            coordinator.lastAnchorsJSON = anchors
            webView.loadHTMLString(full, baseURL: nil)
        } else if anchors != coordinator.lastAnchorsJSON {
            // Same document, comment set changed — re-wrap without a reload so
            // the scroll position is preserved.
            coordinator.lastAnchorsJSON = anchors
            webView.evaluateJavaScript("clipApplyHighlights(\(anchors));", completionHandler: nil)
        }

        // Flash a target anchor when the requested id changes.
        if let id = flashAnchorID, id != coordinator.lastFlashedID {
            coordinator.lastFlashedID = id
            webView.evaluateJavaScript("clipFlash(\(jsString(id.uuidString)));", completionHandler: nil)
        } else if flashAnchorID == nil {
            coordinator.lastFlashedID = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect, onCommentClicked: onCommentClicked)
    }

    // MARK: - JS-argument builders (pure, testable)

    /// JSON array of `{id, quote, prefix, suffix}` for the active comments. Using
    /// JSONSerialization guarantees `<`, `>`, `&`, and quotes in user text are
    /// escaped — this is the only sanctioned way text reaches the DOM-wrapping JS.
    static func anchorsJSON(for comments: [Comment]) -> String {
        let array = comments.map {
            ["id": $0.id.uuidString, "quote": $0.quote, "prefix": $0.prefix, "suffix": $0.suffix]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: array),
              let string = String(data: data, encoding: .utf8) else { return "[]" }
        return string
    }

    /// Encodes a single string as a JS string literal (used for the flash id).
    private func jsString(_ s: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [s]),
              let json = String(data: data, encoding: .utf8) else { return "\"\"" }
        // ["x"] → "x"
        return String(json.dropFirst().dropLast())
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let onSelect: (String, String, String) -> Void
        let onCommentClicked: (UUID) -> Void
        var lastHTML = ""
        var lastAnchorsJSON = "[]"
        var pendingAnchors = "[]"
        var lastFlashedID: UUID?

        init(onSelect: @escaping (String, String, String) -> Void,
             onCommentClicked: @escaping (UUID) -> Void) {
            self.onSelect = onSelect
            self.onCommentClicked = onCommentClicked
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("clipApplyHighlights(\(pendingAnchors));", completionHandler: nil)
        }

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            switch message.name {
            case "selection":
                guard let parsed = Self.parseSelection(message.body) else { return }
                DispatchQueue.main.async { self.onSelect(parsed.quote, parsed.prefix, parsed.suffix) }
            case "commentClicked":
                guard let id = Self.parseCommentClicked(message.body) else { return }
                DispatchQueue.main.async { self.onCommentClicked(id) }
            default:
                return
            }
        }

        // Shape-validation kept pure so it can be unit-tested without a live WebView.

        /// Valid only with a non-empty `quote`; `prefix`/`suffix` default to "".
        static func parseSelection(_ body: Any) -> (quote: String, prefix: String, suffix: String)? {
            guard let dict = body as? [String: Any],
                  let quote = dict["quote"] as? String,
                  !quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            let prefix = dict["prefix"] as? String ?? ""
            let suffix = dict["suffix"] as? String ?? ""
            return (quote, prefix, suffix)
        }

        /// Valid only with a string `id` that parses as a UUID.
        static func parseCommentClicked(_ body: Any) -> UUID? {
            guard let dict = body as? [String: Any],
                  let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString) else { return nil }
            return id
        }
    }

    // MARK: - Injected bridge JS

    private static let bridgeJS = """
    (function () {
      if (window.clipBridgeInstalled) return;
      window.clipBridgeInstalled = true;

      var style = document.createElement('style');
      style.textContent =
        'mark.clip-comment{background:rgba(196,125,78,0.28);border-radius:2px;cursor:pointer;}' +
        'mark.clip-comment.clip-flash{background:rgba(196,125,78,0.65);transition:background .3s;}' +
        '#clip-comment-btn{position:fixed;z-index:99999;display:none;padding:3px 9px;font:600 11px -apple-system,sans-serif;' +
        'color:#fff;background:#C47D4E;border:none;border-radius:5px;cursor:pointer;box-shadow:0 1px 4px rgba(0,0,0,.25);}';
      document.head.appendChild(style);

      var btn = document.createElement('button');
      btn.id = 'clip-comment-btn';
      btn.textContent = '💬 Comment';
      document.body.appendChild(btn);
      btn.addEventListener('mousedown', function (e) { e.preventDefault(); });
      btn.addEventListener('click', function (e) { e.preventDefault(); clipPostSelection(); });

      function hideButton() { btn.style.display = 'none'; }

      document.addEventListener('selectionchange', function () {
        var sel = window.getSelection();
        if (!sel || sel.isCollapsed || sel.rangeCount === 0 || !sel.toString().trim()) { hideButton(); return; }
        var rect = sel.getRangeAt(0).getBoundingClientRect();
        btn.style.top = Math.max(2, rect.top - 30) + 'px';
        btn.style.left = Math.max(2, rect.left) + 'px';
        btn.style.display = 'block';
      });

      window.clipPostSelection = function () {
        var sel = window.getSelection();
        if (!sel || sel.rangeCount === 0) return;
        var range = sel.getRangeAt(0);
        var quote = sel.toString();
        if (!quote.trim()) return;
        var CTX = 30, prefix = '', suffix = '';
        if (range.startContainer.nodeType === 3) {
          prefix = range.startContainer.textContent.substring(0, range.startOffset).slice(-CTX);
        }
        if (range.endContainer.nodeType === 3) {
          suffix = range.endContainer.textContent.substring(range.endOffset).slice(0, CTX);
        }
        window.webkit.messageHandlers.selection.postMessage({ quote: quote, prefix: prefix, suffix: suffix });
        hideButton();
        sel.removeAllRanges();
      };

      window.clipApplyHighlights = function (anchors) {
        document.querySelectorAll('mark.clip-comment').forEach(function (m) {
          var parent = m.parentNode;
          while (m.firstChild) parent.insertBefore(m.firstChild, m);
          parent.removeChild(m);
          parent.normalize();
        });
        if (!Array.isArray(anchors)) return;
        anchors.forEach(function (a) { wrapAnchor(a); });
      };

      function wrapAnchor(a) {
        if (!a || !a.quote) return;
        var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null);
        var candidates = [], node;
        while ((node = walker.nextNode())) {
          if (node.parentNode && node.parentNode.closest && node.parentNode.closest('mark.clip-comment')) continue;
          if (node.parentNode && node.parentNode.id === 'clip-comment-btn') continue;
          var idx = node.textContent.indexOf(a.quote);
          if (idx >= 0) candidates.push({ node: node, idx: idx });
        }
        if (candidates.length === 0) return;
        var chosen = candidates[0];
        if (candidates.length > 1 && a.prefix) {
          var tail = a.prefix.slice(-12);
          for (var i = 0; i < candidates.length; i++) {
            var before = candidates[i].node.textContent.substring(0, candidates[i].idx);
            if (before.endsWith(tail)) { chosen = candidates[i]; break; }
          }
        }
        var range = document.createRange();
        range.setStart(chosen.node, chosen.idx);
        range.setEnd(chosen.node, chosen.idx + a.quote.length);
        var mark = document.createElement('mark');
        mark.className = 'clip-comment';
        mark.setAttribute('data-id', a.id);
        try { range.surroundContents(mark); } catch (e) { return; }
        mark.addEventListener('click', function () {
          window.webkit.messageHandlers.commentClicked.postMessage({ id: a.id });
        });
      }

      window.clipFlash = function (id) {
        var el = document.querySelector('mark.clip-comment[data-id="' + id + '"]');
        if (!el) return;
        el.scrollIntoView({ behavior: 'smooth', block: 'center' });
        el.classList.add('clip-flash');
        setTimeout(function () { el.classList.remove('clip-flash'); }, 1200);
      };
    })();
    """
}
