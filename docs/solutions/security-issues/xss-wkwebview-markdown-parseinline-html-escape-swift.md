---
title: "Stored XSS in WKWebView via unescaped markdown inline renderer"
category: security-issues
date: 2026-04-26
tags: [xss, wkwebview, markdown, swift, html-escape, javascript-bridge, stored-xss, content-security]
component: Sources/ClipCore/RichTextTransformer.swift, Sources/Views/HTMLPreviewView.swift, Sources/Views/CheckableHTMLPreviewView.swift, Sources/Views/NotesView.swift
related:
  - docs/solutions/best-practice/swift-cli-clipboard-dmg-bundling-20260406.md
---

## Problem

A note-taking feature renders user markdown notes in a `WKWebView`. The `parseInline()` function in `RichTextTransformer.swift` accepted raw user text and applied markdown regex transformations (bold, italic, links, code) without HTML-escaping the input first.

**Symptoms:**
- `<script>alert(1)</script>` in a note body executed JavaScript in the preview pane
- `[click](javascript:alert(1))` rendered as a live `javascript:` anchor
- Attack was silent — no crash, no visible error, no user warning

## Root Cause

`parseInline()` passed raw user-supplied text directly into HTML generation via regex substitution. Because the output is rendered in a `WKWebView` that exposes a JavaScript bridge (`window.webkit.messageHandlers.checkbox`), any `<script>` tag or `javascript:` URI in user content became a live XSS vector.

The attack chain: user note body → `NoteStore` → `markdownToHTML()` → `parseInline()` → `WKWebView.loadHTMLString()`.

The severity is higher than typical reflected XSS because the `checkbox` message handler is a native bridge — a successful XSS call invokes native code (state mutation, file I/O), not merely a sandboxed alert.

## Solution

**Step 1 — Add `htmlEscape` as a public static helper on `RichTextTransformer`:**

```swift
public static func htmlEscape(_ text: String) -> String {
    text
        .replacingOccurrences(of: "&", with: "&amp;")  // & MUST be first
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&#x27;")
}
```

Escaping `&` first is mandatory — doing it later would double-encode the entities produced by subsequent replacements.

**Step 2 — Call `htmlEscape` as the first operation in `parseInline`, before any regex:**

```swift
public static func parseInline(_ text: String) -> String {
    var result = htmlEscape(text)          // MUST be first

    // Link regex — runs on already-escaped text; < > in URLs already neutralised
    result = result.replacingOccurrences(
        of: "\\[([^\\]]+)\\]\\(([^)]+)\\)",
        with: "<a href=\"$2\" target=\"_blank\">$1</a>",
        options: .regularExpression
    )

    // Defense-in-depth: strip non-http/mailto hrefs (javascript:, data:, etc.)
    result = result.replacingOccurrences(
        of: " href=\"(?!https?://|mailto:)[^\"]*\"",
        with: " href=\"#\"",
        options: .regularExpression
    )

    // Bold, italic, strikethrough, inline code patterns follow...
    return result
}
```

**Why escape-before-markdown is the only correct ordering:**

HTML entities (`&lt;`, `&gt;`, `&amp;`) contain only alphanumeric characters and `#;`. The markdown regexes look for `*`, `_`, `` ` ``, and `[]()` — none of which appear in an entity. Escaping first does not corrupt markdown syntax.

The reverse (markdown-first, escape-second) destroys the `<a>`, `<strong>`, `<em>`, and `<code>` tags just emitted. One behavioral consequence is intentional: raw HTML typed by the user (`<b>bold</b>`) renders as literal text. This is correct for a markdown-first editor — HTML passthrough would reopen the injection surface.

**Verification table:**

| Input | Before fix | After fix |
|---|---|---|
| `<script>alert(1)</script>` | Executes JS | Renders as literal text |
| `[x](javascript:evil())` | Live `javascript:` anchor | `href="#"` |
| `[x](data:text/html,<h1>)` | Live `data:` anchor | `href="#"` |
| `**bold**` | Renders bold | Still renders bold |
| `&amp;` | Renders as `&` | Renders as `&amp;` (correct) |

## Prevention

### Code Review Signals

Flag any function that:
- Interpolates a `String` parameter representing user text directly into an HTML string literal
- Runs HTML-producing regex replacements (`.replacingOccurrences` emitting tags) on raw input with no prior escape call
- Uses `href`, `src`, or `action` attribute values from user input without a scheme allowlist

The review question: *"At what line does untrusted text first touch an HTML context, and is there an escape call on or before that line?"*

### Trust Boundary Rule

Every rendering pipeline has exactly one trust boundary — where data crosses from user-data space into HTML/JS rendering space. Escaping must happen at that boundary:

- **Not before** — double-escape risk if escaped text is then escaped again upstream
- **Not after** — injection risk; the damage is already done by the time HTML emits

If the pipeline has multiple entry points (inline parser, heading parser, table renderer), each entry point is its own trust boundary and must escape independently.

### Swift WKWebView Safety Checklist

- [ ] `configuration.preferences.javaScriptEnabled` is `false` unless the WebView loads fully controlled, non-user-influenced content
- [ ] Each `WKScriptMessageHandler` has a minimal, typed interface — validates `body` against an expected type; rejects unexpected shapes
- [ ] No message handler performs file I/O or shell execution based solely on unvalidated message content
- [ ] HTML passed to `loadHTMLString` has all user-authored substrings HTML-escaped
- [ ] Link navigation intercepted via `decidePolicyFor navigationAction`: only `https`, `http`, `mailto` allowed; all others cancelled
- [ ] User content never passed through `evaluateJavaScript(_:)` without escaping — prefer `callAsyncJavaScript(_:arguments:)` which parameterizes values safely

### Other Renderer Functions at Risk

Functions in the same pipeline that accept raw user text and emit HTML are equally vulnerable:

- **Heading parser** — `<img onerror=...>` in a heading injects an element
- **Code block / inline code** — most commonly forgotten; angle brackets in code examples (`<T>`, `<div>`) must be escaped
- **Table cell renderer** — `</td></tr><script>` terminates table structure and injects script
- **Image alt text and title attributes** — quotes in titles can break attribute context
- **HTML passthrough blocks** — if the renderer allows raw HTML, it is a deliberate escape hatch and must be disabled for user-generated content

## Test Cases

```swift
// script tag — must not execute
XCTAssertFalse(RichTextTransformer.parseInline("<script>alert(1)</script>").contains("<script"))

// javascript: link — href must be neutralised
XCTAssertFalse(RichTextTransformer.parseInline("[x](javascript:alert(1))").contains("href=\"javascript:"))

// data: link — href must be neutralised
XCTAssertFalse(RichTextTransformer.parseInline("[x](data:text/html,hi)").contains("href=\"data:"))

// & entity — must not double-encode
let ampResult = RichTextTransformer.parseInline("&amp;")
XCTAssertTrue(ampResult.contains("&amp;amp;"))  // one level of escaping applied

// bold markdown — must still render after escaping
XCTAssertTrue(RichTextTransformer.parseInline("**bold**").contains("<strong>bold</strong>"))
```

## Related Files

- `Sources/ClipCore/RichTextTransformer.swift` — fix location (lines ~307–337)
- `Sources/Views/HTMLPreviewView.swift` — base `WKWebView` wrapper
- `Sources/Views/CheckableHTMLPreviewView.swift` — variant exposing the `checkbox` JS bridge
- `Sources/Views/NotesView.swift` — renders note body via `CheckableHTMLPreviewView`
- `Sources/Views/MinimalNotesView.swift` — alternate notes renderer
