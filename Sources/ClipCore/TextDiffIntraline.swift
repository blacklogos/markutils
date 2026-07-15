import Foundation

// Intra-line diff refinement for TextDiff. Pairs the removed/added lines of a
// replace block and marks which tokens actually changed within each pair, so
// the renderer can highlight words/characters instead of whole lines.
//
// Precision levels:
//   .line      — no intra-line work; whole changed lines are highlighted (old behavior)
//   .word      — token = word / whitespace / punctuation run
//   .character — token = grapheme
//   .smart     — per line pair: character when the lines are near-identical,
//                word when they share enough words, whole line otherwise
public extension TextDiff {

    enum Precision {
        case smart, line, word, character
    }

    /// A run within a changed line. `changed == false` is unchanged context.
    struct Segment: Equatable {
        public let changed: Bool
        public let text: String
        public init(changed: Bool, text: String) {
            self.changed = changed
            self.text = text
        }
    }

    /// A diff line plus optional intra-line segments. `segments == nil` means
    /// highlight the whole line (unpaired line, .line precision, or fallback).
    struct AnnotatedLine: Equatable {
        public let kind: LineKind
        public let text: String
        public let segments: [Segment]?
        public init(kind: LineKind, text: String, segments: [Segment]? = nil) {
            self.kind = kind
            self.text = text
            self.segments = segments
        }
    }

    /// Line diff with intra-line change annotation at the requested precision.
    static func annotatedDiff(_ a: String, _ b: String, precision: Precision = .smart) -> [AnnotatedLine] {
        let base = diff(a, b)
        guard precision != .line else {
            return base.map { AnnotatedLine(kind: $0.kind, text: $0.text) }
        }

        var result: [AnnotatedLine] = []
        var idx = 0
        while idx < base.count {
            guard base[idx].kind == .removed else {
                result.append(AnnotatedLine(kind: base[idx].kind, text: base[idx].text))
                idx += 1
                continue
            }
            // Replace block: a run of removals optionally followed by a run of additions.
            var removed: [String] = []
            while idx < base.count, base[idx].kind == .removed { removed.append(base[idx].text); idx += 1 }
            var added: [String] = []
            while idx < base.count, base[idx].kind == .added { added.append(base[idx].text); idx += 1 }

            // Pair lines positionally; leftovers stay whole-line highlighted.
            let pairCount = min(removed.count, added.count)
            var annotatedAdded: [AnnotatedLine] = []
            for k in 0..<removed.count {
                if k < pairCount {
                    let (rSegs, aSegs) = intralineSegments(removed[k], added[k], precision: precision)
                    result.append(AnnotatedLine(kind: .removed, text: removed[k], segments: rSegs))
                    annotatedAdded.append(AnnotatedLine(kind: .added, text: added[k], segments: aSegs))
                } else {
                    result.append(AnnotatedLine(kind: .removed, text: removed[k]))
                }
            }
            result += annotatedAdded
            for k in pairCount..<added.count {
                result.append(AnnotatedLine(kind: .added, text: added[k]))
            }
        }
        return result
    }

    // MARK: - Internals

    // LCS table bound per line pair; beyond this fall back to whole-line highlight.
    private static let maxTokensPerLine = 600

    /// One LCS pass per tier: tokenize, flag changes via the shared engine, and
    /// derive both the segments and the similarity from the same flags.
    private static func intralineSegments(_ removed: String, _ added: String, precision: Precision)
        -> ([Segment]?, [Segment]?) {
        func attempt(_ mode: Precision) -> (tokens: ([String], [String]), flags: ([Bool], [Bool]))? {
            let r = tokenize(removed, by: mode)
            let a = tokenize(added, by: mode)
            guard r.count <= maxTokensPerLine, a.count <= maxTokensPerLine,
                  !r.isEmpty, !a.isEmpty else { return nil }
            return ((r, a), lcsFlags(r, a))
        }
        func segments(_ t: ([String], [String]), _ f: ([Bool], [Bool])) -> ([Segment]?, [Segment]?) {
            (mergeSegments(t.0, f.0), mergeSegments(t.1, f.1))
        }

        switch precision {
        case .line:
            return (nil, nil)
        case .word, .character:
            guard let (tokens, flags) = attempt(precision) else { return (nil, nil) }
            return segments(tokens, flags)
        case .smart:
            // Character tier: near-identical short lines (typo-level edits).
            if max(removed.count, added.count) <= 200, let (tokens, flags) = attempt(.character) {
                let unchanged = flags.0.lazy.filter { !$0 }.count
                if Double(unchanged) / Double(max(tokens.0.count, tokens.1.count)) >= 0.9 {
                    return segments(tokens, flags)
                }
            }
            // Word tier: similarity over word tokens only (whitespace inflates it).
            guard let (tokens, flags) = attempt(.word) else { return (nil, nil) }
            let rWords = zip(tokens.0, flags.0).filter { !$0.0.allSatisfy(\.isWhitespace) }
            let aWords = zip(tokens.1, flags.1).filter { !$0.0.allSatisfy(\.isWhitespace) }
            let common = rWords.lazy.filter { !$0.1 }.count
            let denom = max(rWords.count, aWords.count)
            guard denom > 0, Double(common) / Double(denom) >= 0.3 else { return (nil, nil) }
            return segments(tokens, flags)
        }
    }

    /// Word mode: maximal runs of alphanumerics, runs of whitespace, or a single
    /// other character (punctuation). Character mode: one token per grapheme.
    private static func tokenize(_ text: String, by mode: Precision) -> [String] {
        if mode == .character { return text.map(String.init) }
        var tokens: [String] = []
        var current = ""
        var currentKind: Int = -1  // 0 = word, 1 = whitespace
        for char in text {
            let kind: Int
            if char.isLetter || char.isNumber { kind = 0 }
            else if char.isWhitespace { kind = 1 }
            else { kind = 2 }
            if kind == 2 {
                if !current.isEmpty { tokens.append(current); current = "" }
                tokens.append(String(char))  // punctuation: single-char token
                currentKind = -1
            } else if kind == currentKind {
                current.append(char)
            } else {
                if !current.isEmpty { tokens.append(current) }
                current = String(char)
                currentKind = kind
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    /// Coalesces consecutive tokens with the same changed flag into segments.
    private static func mergeSegments(_ tokens: [String], _ flags: [Bool]) -> [Segment] {
        var segments: [Segment] = []
        for (token, changed) in zip(tokens, flags) {
            if let last = segments.last, last.changed == changed {
                segments[segments.count - 1] = Segment(changed: changed, text: last.text + token)
            } else {
                segments.append(Segment(changed: changed, text: token))
            }
        }
        return segments
    }
}
