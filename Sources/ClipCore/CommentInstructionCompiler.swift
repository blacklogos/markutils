import Foundation

/// Turns comments + source markdown into the two paste-ready instruction blocks
/// the Creator hands to her external AI agent. Pure, deterministic, no DOM.
///
/// A note is rendered as a readable callout — `💬 INSTRUCTION (on "<quote>"):
/// <note>` — chosen over CriticMarkup so both the agent and a human skimming the
/// paste read it plainly. The source is reproduced verbatim; callouts are the
/// only inserted lines.
public enum CommentInstructionCompiler {

    /// Standing instruction prepended to both outputs so the agent knows the
    /// 💬 lines are directives about the adjacent quoted text.
    public static let preamble = """
    The text below is a markdown document with inline review notes from its author. \
    Each note is marked `💬 INSTRUCTION (on "…")` and asks for a change to the quoted \
    text it refers to. Apply the requested edits and return the revised markdown only, \
    without the 💬 lines.
    """

    private static let orphanHeader = "Notes that no longer match the text:"

    // MARK: - Section

    /// Preamble + the comment's enclosing block (verbatim) + its callout. Falls
    /// back to the bare quote if the block can't be located in `text`.
    public static func section(for comment: Comment, in text: String) -> String {
        let block = CommentAnchor.enclosingBlock(forQuote: comment.quote,
                                                 prefix: comment.prefix,
                                                 suffix: comment.suffix,
                                                 in: text) ?? comment.quote
        return preamble + "\n\n" + block + "\n\n" + callout(for: comment)
    }

    // MARK: - Whole file

    /// Preamble + the full source with each active comment's callout inserted on
    /// its own line just after the line carrying the quote. Comments are ordered
    /// by source position. Any `needsReview` comment (or one that no longer
    /// locates) is appended under a labeled section so nothing is lost (R14).
    public static func wholeFile(comments: [Comment], in text: String) -> String {
        var orphans: [Comment] = []
        var located: [(line: Int, order: Int, callout: String)] = []

        for (idx, comment) in comments.enumerated() {
            if comment.status == .needsReview {
                orphans.append(comment)
                continue
            }
            guard let range = CommentAnchor.locate(quote: comment.quote,
                                                   prefix: comment.prefix,
                                                   suffix: comment.suffix,
                                                   in: text) else {
                orphans.append(comment)
                continue
            }
            located.append((lineIndex(ofEndOf: range, in: text), idx, callout(for: comment)))
        }

        located.sort { $0.line != $1.line ? $0.line < $1.line : $0.order < $1.order }

        var body = text
        if !located.isEmpty {
            var inserts: [Int: [String]] = [:]
            for item in located { inserts[item.line, default: []].append(item.callout) }

            var out: [String] = []
            for (i, line) in text.components(separatedBy: "\n").enumerated() {
                out.append(line)
                if let callouts = inserts[i] { out.append(contentsOf: callouts) }
            }
            body = out.joined(separator: "\n")
        }

        var result = preamble + "\n\n" + body
        if !orphans.isEmpty {
            result += "\n\n---\n\n" + orphanHeader + "\n"
                + orphans.map { callout(for: $0) }.joined(separator: "\n")
        }
        return result
    }

    // MARK: - Callout

    /// `💬 INSTRUCTION (on "<quote>"): <note>` on a single line. Quote and note
    /// are flattened to one line so a multi-line note can't inject block
    /// structure into the surrounding markdown.
    static func callout(for comment: Comment) -> String {
        "💬 INSTRUCTION (on \"\(flatten(comment.quote))\"): \(flatten(comment.note))"
    }

    private static func flatten(_ s: String) -> String {
        s.replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    /// Zero-based index (in the `\n`-split line array) of the line containing the
    /// last character of `range`.
    private static func lineIndex(ofEndOf range: Range<String.Index>, in text: String) -> Int {
        let lastChar = range.isEmpty || range.upperBound == text.startIndex
            ? range.lowerBound
            : text.index(before: range.upperBound)
        return text[text.startIndex...lastChar].reduce(0) { $1 == "\n" ? $0 + 1 : $0 }
    }
}
