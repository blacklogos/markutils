---
name: WebView hardening — navigation policy + jsString U+2028/29 escapes
description: Preview WKWebViews navigate in-place to http(s) links from untrusted markdown (phishing surface); jsString should escape U+2028/2029 defensively
type: todo
status: pending
priority: p3
issue_id: "028"
tags: [code-review, security, webview]
dependencies: []
---

## Problem Statement / Findings

1. No preview WebView implements `decidePolicyFor navigationAction` (HTMLPreviewView, CheckableHTMLPreviewView, AnnotatableHTMLPreviewView). `parseInline` already strips `javascript:`/`file:` hrefs, but an `http(s)` link in an opened markdown file navigates the preview in-place to an arbitrary page (in-app phishing, beacon on click).
2. `jsString` (DiffHTMLRenderer.swift:112-116) leaves U+2028/U+2029 unescaped. Not exploitable on macOS 14+ JavaScriptCore (ES2019 allows them in string literals — verified, and the `</`→`<\/` escape correctly blocks `</script>` breakouts), but the escaper should be engine-independent. Same note applies to AnnotatableHTMLPreviewView.anchorsJSON.

Reported by: security-sentinel (both P3, breakout payloads tested).

## Proposed Solutions

1. Shared `WKNavigationDelegate` policy: allow initial `loadHTMLString` (about:blank), cancel other top-level navigations, route link clicks to `NSWorkspace.shared.open`.
2. Append `.replacingOccurrences(of: "\u{2028}", with: "\\u2028")` (and 2029) in both jsString helpers.
- Effort: Small | Risk: Low

## Acceptance Criteria
- [ ] Clicking an http link in Reader preview opens default browser, preview stays put
- [ ] jsString output contains no raw U+2028/2029
