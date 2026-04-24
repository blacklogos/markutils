import SwiftUI

struct KeywordReferenceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                section("Keyboard Shortcuts", items: shortcuts)
                Divider()
                section("Keyword Expansions", items: keywords)
                Divider()
                section("Markdown Quick Reference", items: markdown)
            }
            .padding(20)
        }
        .frame(width: 380, height: 480)
        .background(AppColors.toolbarBackground)
    }

    private func section(_ title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.accent)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 0) {
                        Text(item.0)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(width: 160, alignment: .leading)
                        Text(item.1)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(4)
                    .padding(.bottom, 2)
                }
            }
        }
    }

    private let shortcuts: [(String, String)] = [
        ("⌥A",              "Open / close Notes panel"),
        ("⌘N",              "New note (guard: empty note)"),
        ("⌘C",              "Copy full note to clipboard"),
    ]

    private let keywords: [(String, String)] = [
        ("::today",         "Today's date (long format)"),
        ("::tomorrow",      "Tomorrow's date"),
        ("::meeting",       "Meeting Notes template"),
        ("::proposal",      "Proposal Structure template"),
        ("::slides",        "Slide Outline template"),
        ("::table",         "Comparison Table template"),
        ("[] or [ ]",       "→ - [ ]  (checkbox item)"),
    ]

    private let markdown: [(String, String)] = [
        ("# Heading 1",     "Large heading"),
        ("## Heading 2",    "Medium heading"),
        ("### Heading 3",   "Small heading"),
        ("**bold**",        "Bold text"),
        ("*italic*",        "Italic text"),
        ("~~strike~~",      "Strikethrough"),
        ("`code`",          "Inline code"),
        ("> quote",         "Blockquote"),
        ("- item",          "Unordered list"),
        ("- [ ] task",      "Unchecked task"),
        ("- [x] task",      "Checked task"),
    ]
}
