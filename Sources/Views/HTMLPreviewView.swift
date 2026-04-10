import SwiftUI
import WebKit

struct HTMLPreviewView: NSViewRepresentable {
    let htmlContent: String

    private var fullHTML: String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
            :root {
                color-scheme: light dark;
                --bg:       #F7F4EF;
                --fg:       #2C2C2C;
                --fg2:      #8A8078;
                --accent:   #C47D4E;
                --border:   rgba(160,140,120,0.2);
                --code-bg:  rgba(160,140,120,0.12);
                --th-bg:    rgba(160,140,120,0.1);
                --even-bg:  rgba(160,140,120,0.04);
            }
            @media (prefers-color-scheme: dark) {
                :root {
                    --bg:     #252525;
                    --fg:     #E8E0D8;
                    --fg2:    #8A8078;
                    --accent: #D4956A;
                    --border: rgba(160,140,120,0.18);
                    --code-bg:rgba(160,140,120,0.1);
                    --th-bg:  rgba(160,140,120,0.08);
                    --even-bg:rgba(160,140,120,0.03);
                }
            }
            body {
                font-family: Georgia, "Times New Roman", serif;
                font-size: 14px;
                line-height: 1.7;
                padding: 14px 18px;
                margin: 0;
                color: var(--fg);
                background: var(--bg);
            }
            h1, h2, h3, h4 {
                font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
                font-weight: 600;
                color: var(--fg);
            }
            h1 { font-size: 1.75em; margin: 0.8em 0 0.4em; border-bottom: 1px solid var(--border); padding-bottom: 0.3em; }
            h2 { font-size: 1.35em; margin: 0.8em 0 0.4em; border-bottom: 1px solid var(--border); padding-bottom: 0.2em; }
            h3 { font-size: 1.1em;  margin: 0.6em 0 0.3em; }
            p  { margin: 0.5em 0; }
            ul, ol { padding-left: 1.5em; margin: 0.4em 0; }
            li { margin: 0.2em 0; }
            a  { color: var(--accent); text-decoration: none; }
            a:hover { text-decoration: underline; }
            code {
                font-family: "SF Mono", Menlo, monospace;
                font-size: 0.88em;
                padding: 0.15em 0.4em;
                border-radius: 3px;
                background: var(--code-bg);
                color: var(--fg);
            }
            pre {
                padding: 12px;
                border-radius: 6px;
                background: var(--code-bg);
                overflow-x: auto;
            }
            pre code { padding: 0; background: none; }
            blockquote {
                margin: 0.5em 0;
                padding: 0.3em 1em;
                border-left: 3px solid var(--accent);
                color: var(--fg2);
            }
            blockquote p { margin: 0.2em 0; }
            hr {
                border: none;
                border-top: 1px solid var(--border);
                margin: 1em 0;
            }
            strong { font-weight: 700; }
            em     { font-style: italic; }
            table  { border-collapse: collapse; width: 100%; margin: 0.6em 0; font-size: 0.94em; }
            th, td { border: 1px solid var(--border); padding: 6px 12px; text-align: left; vertical-align: top; }
            th     { background: var(--th-bg); font-weight: 600;
                     font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
            tbody tr:nth-child(even) td { background: var(--even-bg); }
            .clip-footer {
                margin-top: 2em;
                padding-top: 0.8em;
                border-top: 1px solid var(--border);
                text-align: center;
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                font-size: 0.75em;
                color: var(--fg2);
                letter-spacing: 0.02em;
            }
        </style>
        </head>
        <body>\(htmlContent)<div class="clip-footer">MD Preview by Clip</div></body>
        </html>
        """
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(fullHTML, baseURL: nil)
    }
}
