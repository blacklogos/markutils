import SwiftUI
import AppKit

// NSTextView-backed markdown editor with:
// - Inline markdown attribute styling (Obsidian-style: markers visible but dimmed)
// - Keyword expansion on trigger strings
// - Plain-text paste/copy (rich text never leaves/enters the editor)
//
// isRichText = true is required for NSTextStorage attribute display.
// PlainTextView overrides paste/copy/cut to strip attributes.
struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let contentSize = scrollView.contentSize
        let textView = PlainTextView(frame: NSRect(origin: .zero, size: contentSize))
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.containerSize = NSSize(
            width: contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        // isRichText = true (default) is required for NSTextStorage attributes to render.
        // Paste/copy are overridden in PlainTextView to keep plain-text semantics.
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        textView.delegate = context.coordinator
        textView.textStorage?.delegate = context.coordinator
        textView.string = text

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        guard !context.coordinator.isUpdating, textView.string != text else { return }
        textView.string = text
        // Re-apply styling after external text replacement
        if let storage = textView.textStorage {
            context.coordinator.applyMarkdownAttributes(to: storage)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Plain-text NSTextView subclass

    // Strips attributes on paste/copy so markdown markers are never styled by pasting.
    private class PlainTextView: NSTextView {
        override func paste(_ sender: Any?) {
            guard let str = NSPasteboard.general.string(forType: .string) else { return }
            insertText(str, replacementRange: selectedRange())
        }
        override func copy(_ sender: Any?) {
            let sel = (string as NSString).substring(with: selectedRange())
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(sel, forType: .string)
        }
        override func cut(_ sender: Any?) {
            copy(sender)
            insertText("", replacementRange: selectedRange())
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var parent: MarkdownTextEditor
        var isUpdating = false  // re-entrancy guard for insertText keyword expansion

        init(parent: MarkdownTextEditor) {
            self.parent = parent
        }

        // MARK: NSTextViewDelegate — keyword expansion

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isUpdating else { return }

            expandKeywords(in: textView)

            let newText = textView.string
            DispatchQueue.main.async { [weak self] in
                self?.parent.text = newText
            }
        }

        // MARK: NSTextStorageDelegate — inline markdown styling
        //
        // .editedCharacters guard prevents recursion: addAttributes/setAttributes calls
        // inside this callback fire the delegate again with .editedAttributes only,
        // which this guard blocks.

        func textStorage(_ textStorage: NSTextStorage,
                         didProcessEditing editedMask: NSTextStorageEditActions,
                         range editedRange: NSRange,
                         changeInLength delta: Int) {
            guard editedMask.contains(.editedCharacters) else { return }
            applyMarkdownAttributes(to: textStorage)
        }

        // MARK: Inline markdown attribute styling

        func applyMarkdownAttributes(to storage: NSTextStorage) {
            let text = storage.string
            guard !text.isEmpty else { return }
            let nsText = text as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)
            // Monospaced base font — full Unicode (Vietnamese + Latin) via SF Mono / Menlo
            let baseFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

            // Reset all text to base appearance (isRichText=true means we own all attributes)
            storage.setAttributes([
                .font: baseFont,
                .foregroundColor: NSColor.labelColor
            ], range: fullRange)

            // Inline patterns — applied before headings so headings win on overlap
            styleInline(in: storage, text: nsText, pattern: Self.boldRegex,
                        markerAttrs: [.foregroundColor: NSColor.tertiaryLabelColor],
                        contentAttrs: [.font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)])

            styleInline(in: storage, text: nsText, pattern: Self.italicRegex,
                        markerAttrs: [.foregroundColor: NSColor.tertiaryLabelColor],
                        contentAttrs: [.font: Self.italicFont])

            styleInline(in: storage, text: nsText, pattern: Self.strikeRegex,
                        markerAttrs: [.foregroundColor: NSColor.tertiaryLabelColor],
                        contentAttrs: [
                            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                            .foregroundColor: NSColor.secondaryLabelColor
                        ])

            styleInline(in: storage, text: nsText, pattern: Self.codeRegex,
                        markerAttrs: [.foregroundColor: NSColor.tertiaryLabelColor],
                        contentAttrs: [
                            // same size as body — just highlight background
                            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                            .backgroundColor: NSColor.tertiaryLabelColor.withAlphaComponent(0.08)
                        ])

            // Headings — bold + accent color, NO size change (keeps fixed-width grid intact)
            Self.headingRegex?.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                guard let match else { return }
                storage.addAttributes([
                    .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold),
                    .foregroundColor: Self.accentColor
                ], range: match.range)
            }

            // Blockquotes — secondary color, > marker dimmed
            Self.quoteRegex?.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                guard let match else { return }
                storage.addAttributes([.foregroundColor: NSColor.secondaryLabelColor], range: match.range)
                storage.addAttributes([.foregroundColor: NSColor.tertiaryLabelColor], range: match.range(at: 1))
            }
        }

        // Applies dimmed attributes to markers and formatting to content for a given pattern.
        // Capture group 1 must be the content (markers are before/after it in the full match).
        private func styleInline(in storage: NSTextStorage, text: NSString,
                                 pattern: NSRegularExpression?,
                                 markerAttrs: [NSAttributedString.Key: Any],
                                 contentAttrs: [NSAttributedString.Key: Any]) {
            let fullRange = NSRange(location: 0, length: text.length)
            pattern?.enumerateMatches(in: text as String, range: fullRange) { match, _, _ in
                guard let match, match.numberOfRanges >= 2 else { return }
                let contentRange = match.range(at: 1)
                let openLen = contentRange.location - match.range.location
                if openLen > 0 {
                    storage.addAttributes(markerAttrs, range: NSRange(location: match.range.location, length: openLen))
                }
                storage.addAttributes(contentAttrs, range: contentRange)
                let closeStart = contentRange.upperBound
                let closeLen = match.range.upperBound - closeStart
                if closeLen > 0 {
                    storage.addAttributes(markerAttrs, range: NSRange(location: closeStart, length: closeLen))
                }
            }
        }

        // MARK: Keyword expansion

        private func expandKeywords(in textView: NSTextView) {
            let cursorLoc = textView.selectedRange().location
            guard cursorLoc > 0 else { return }

            let fullString = textView.string as NSString
            let prefix = fullString.substring(to: cursorLoc)

            let triggers: [(trigger: String, expansion: () -> String)] = [
                ("::meeting",  { self.snippetContent(for: "Meeting Notes") }),
                ("::proposal", { self.snippetContent(for: "Proposal Structure") }),
                ("::slides",   { self.snippetContent(for: "Slide Outline") }),
                ("::table",    { self.snippetContent(for: "Comparison Table") }),
                ("::tomorrow", { self.formattedDate(offset: 1) }),
                ("::today",    { self.formattedDate(offset: 0) }),
                ("[ ]",        { "- [ ] " }),
                ("[]",         { "- [ ] " }),
            ]

            for (trigger, expansion) in triggers {
                guard prefix.hasSuffix(trigger) else { continue }
                let nsLen = (trigger as NSString).length
                let triggerRange = NSRange(location: cursorLoc - nsLen, length: nsLen)
                isUpdating = true
                textView.insertText(expansion(), replacementRange: triggerRange)
                isUpdating = false
                return
            }
        }

        // MARK: Static resources (compiled once)

        private static let boldRegex    = try? NSRegularExpression(pattern: #"\*\*(.+?)\*\*"#)
        private static let italicRegex  = try? NSRegularExpression(pattern: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#)
        private static let strikeRegex  = try? NSRegularExpression(pattern: #"~~(.+?)~~"#)
        private static let codeRegex    = try? NSRegularExpression(pattern: #"`([^`]+)`"#)
        private static let headingRegex = try? NSRegularExpression(pattern: #"^(#{1,3}) (.+)$"#, options: .anchorsMatchLines)
        private static let quoteRegex   = try? NSRegularExpression(pattern: #"^(>) (.+)$"#,      options: .anchorsMatchLines)

        private static let italicFont: NSFont = {
            NSFontManager.shared.convert(
                .monospacedSystemFont(ofSize: 13, weight: .regular),
                toHaveTrait: .italicFontMask
            )
        }()

        private static let accentColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: 212/255, green: 149/255, blue: 106/255, alpha: 1)
                : NSColor(srgbRed: 196/255, green: 125/255, blue: 78/255, alpha: 1)
        }

        // MARK: Helpers

        private func snippetContent(for name: String) -> String {
            SnippetStore.shared.snippets
                .first { $0.isBuiltIn && $0.name.localizedCaseInsensitiveContains(name) }
                .map { $0.content } ?? ""
        }

        private func formattedDate(offset days: Int) -> String {
            var components = DateComponents()
            components.day = days
            let date = Calendar.current.date(byAdding: components, to: Date()) ?? Date()
            let fmt = DateFormatter()
            fmt.dateStyle = .long
            fmt.timeStyle = .none
            return fmt.string(from: date)
        }
    }
}
