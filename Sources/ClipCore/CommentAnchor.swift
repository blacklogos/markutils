import Foundation

/// Pure-Foundation anchoring for reader comments. Operates only on raw markdown
/// strings — no DOM, no WebKit, no AST — so it is deterministic and unit-testable
/// and usable headless. Anchoring is by quoted text + surrounding context: a
/// comment re-locates its span on reload and degrades to `needsReview` (never
/// deleted) when its text has vanished.
public enum CommentAnchor {

    // MARK: - Locate

    /// Finds the character range of `quote` in `text`. When `quote` occurs more
    /// than once, the occurrence whose surrounding text best matches the stored
    /// `prefix`/`suffix` wins; with no distinguishing context, the first
    /// occurrence is returned. Empty quote or empty text yields `nil`.
    public static func locate(quote: String,
                              prefix: String = "",
                              suffix: String = "",
                              in text: String) -> Range<String.Index>? {
        guard !quote.isEmpty, !text.isEmpty else { return nil }

        var occurrences: [Range<String.Index>] = []
        var searchStart = text.startIndex
        while let r = text.range(of: quote, range: searchStart..<text.endIndex) {
            occurrences.append(r)
            // Advance one character past the match start so overlapping repeats
            // are still found, and we always make progress.
            searchStart = text.index(after: r.lowerBound)
            if searchStart >= text.endIndex { break }
        }

        guard let first = occurrences.first else { return nil }
        guard occurrences.count > 1 else { return first }

        var best = first
        var bestScore = -1
        for r in occurrences {
            let preceding = text[text.startIndex..<r.lowerBound]
            let following = text[r.upperBound..<text.endIndex]
            let score = commonSuffixCount(preceding, prefix) + commonPrefixCount(following, suffix)
            if score > bestScore {            // strict > keeps the earliest on a tie
                bestScore = score
                best = r
            }
        }
        return best
    }

    // MARK: - Re-anchor

    /// Re-classifies a comment against new source text: `active` if its quote is
    /// still locatable, `needsReview` otherwise. Never deletes — an orphaned
    /// comment is retained so the Creator can repair or remove it (R12, R13).
    public static func reanchor(_ comment: Comment, in text: String) -> Comment {
        var updated = comment
        updated.status = locate(quote: comment.quote,
                                prefix: comment.prefix,
                                suffix: comment.suffix,
                                in: text) != nil ? .active : .needsReview
        return updated
    }

    // MARK: - Enclosing block

    /// Expands a located span to its enclosing block — the full paragraph for a
    /// phrase mid-paragraph, the single line for a heading, or the single item
    /// for a list item — by walking to blank-line / heading / list boundaries.
    /// Returns the block substring, or `nil` for empty input.
    public static func enclosingBlock(of range: Range<String.Index>, in text: String) -> String? {
        guard !text.isEmpty else { return nil }
        let lines = lineRanges(text)
        guard !lines.isEmpty else { return nil }

        let startLine = lineIndex(for: range.lowerBound, in: lines)
        // Anchor the end on the last character actually covered by the span.
        let lastCharIndex = range.isEmpty ? range.lowerBound
            : (range.upperBound > text.startIndex ? text.index(before: range.upperBound) : range.lowerBound)
        let endLine = max(startLine, lineIndex(for: lastCharIndex, in: lines))

        let firstTrimmed = trimmed(text, lines[startLine])

        // Heading or list item: the block is exactly that line.
        if firstTrimmed.hasPrefix("#") || isListItem(firstTrimmed) {
            return String(text[lines[startLine]])
        }

        // Paragraph: expand up and down across non-blank, non-boundary lines.
        var top = startLine
        while top > 0, isParagraphContinuation(trimmed(text, lines[top - 1])) {
            top -= 1
        }
        var bottom = endLine
        while bottom < lines.count - 1, isParagraphContinuation(trimmed(text, lines[bottom + 1])) {
            bottom += 1
        }
        return String(text[lines[top].lowerBound..<lines[bottom].upperBound])
    }

    /// Convenience: locate a quote and return its enclosing block in one step.
    public static func enclosingBlock(forQuote quote: String,
                                      prefix: String = "",
                                      suffix: String = "",
                                      in text: String) -> String? {
        guard let range = locate(quote: quote, prefix: prefix, suffix: suffix, in: text) else { return nil }
        return enclosingBlock(of: range, in: text)
    }

    // MARK: - Line helpers

    /// Content ranges of each line (newline excluded). Always returns at least one.
    private static func lineRanges(_ text: String) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var lineStart = text.startIndex
        var i = text.startIndex
        while i < text.endIndex {
            if text[i] == "\n" {
                result.append(lineStart..<i)
                lineStart = text.index(after: i)
            }
            i = text.index(after: i)
        }
        result.append(lineStart..<text.endIndex)
        return result
    }

    private static func lineIndex(for idx: String.Index, in lines: [Range<String.Index>]) -> Int {
        for (n, r) in lines.enumerated() where idx <= r.upperBound {
            return n
        }
        return lines.count - 1
    }

    private static func trimmed(_ text: String, _ range: Range<String.Index>) -> String {
        String(text[range]).trimmingCharacters(in: .whitespaces)
    }

    private static func isListItem(_ trimmed: String) -> Bool {
        trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ")
            || trimmed.range(of: #"^\d{1,9}[.)]\s"#, options: .regularExpression) != nil
    }

    /// A line continues the current paragraph when it is non-blank and not the
    /// start of a new block (heading or list item).
    private static func isParagraphContinuation(_ trimmed: String) -> Bool {
        !trimmed.isEmpty && !trimmed.hasPrefix("#") && !isListItem(trimmed)
    }

    // MARK: - Context scoring

    /// Length of the longest common suffix of `a` and `b` (how well a stored
    /// prefix matches the text immediately before an occurrence).
    private static func commonSuffixCount(_ a: Substring, _ b: String) -> Int {
        var ai = a.endIndex, bi = b.endIndex, count = 0
        while ai > a.startIndex, bi > b.startIndex {
            let na = a.index(before: ai), nb = b.index(before: bi)
            if a[na] != b[nb] { break }
            ai = na; bi = nb; count += 1
        }
        return count
    }

    /// Length of the longest common prefix of `a` and `b` (how well a stored
    /// suffix matches the text immediately after an occurrence).
    private static func commonPrefixCount(_ a: Substring, _ b: String) -> Int {
        var ai = a.startIndex, bi = b.startIndex, count = 0
        while ai < a.endIndex, bi < b.endIndex {
            if a[ai] != b[bi] { break }
            ai = a.index(after: ai); bi = b.index(after: bi); count += 1
        }
        return count
    }
}
