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

    enum Precision: String, CaseIterable {
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

    private static func intralineSegments(_ removed: String, _ added: String, precision: Precision)
        -> ([Segment]?, [Segment]?) {
        let mode = precision == .smart ? smartMode(removed, added) : precision
        guard mode == .word || mode == .character else { return (nil, nil) }

        let rTokens = tokenize(removed, by: mode)
        let aTokens = tokenize(added, by: mode)
        guard rTokens.count <= maxTokensPerLine, aTokens.count <= maxTokensPerLine,
              !rTokens.isEmpty, !aTokens.isEmpty else { return (nil, nil) }

        let (rChanged, aChanged) = changedFlags(rTokens, aTokens)
        return (mergeSegments(rTokens, rChanged), mergeSegments(aTokens, aChanged))
    }

    /// Smart heuristic: character precision for near-identical short lines (typo-level
    /// edits), word precision when the lines share enough words, whole line otherwise.
    private static func smartMode(_ removed: String, _ added: String) -> Precision {
        // Character tier: char-level similarity ≥ 0.9 on short lines → typo-level edit.
        if max(removed.count, added.count) <= 200 {
            let rChars = tokenize(removed, by: .character)
            let aChars = tokenize(added, by: .character)
            let denom = max(rChars.count, aChars.count)
            if denom > 0, Double(lcsLength(rChars, aChars)) / Double(denom) >= 0.9 {
                return .character
            }
        }
        // Word tier: similarity over words only (whitespace tokens would inflate it).
        let rWords = tokenize(removed, by: .word).filter { !$0.allSatisfy(\.isWhitespace) }
        let aWords = tokenize(added, by: .word).filter { !$0.allSatisfy(\.isWhitespace) }
        let denom = max(rWords.count, aWords.count)
        guard denom > 0, rWords.count <= maxTokensPerLine, aWords.count <= maxTokensPerLine else {
            return .line
        }
        if Double(lcsLength(rWords, aWords)) / Double(denom) >= 0.3 { return .word }
        return .line
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

    /// LCS over token arrays; marks tokens outside the common subsequence as changed.
    private static func changedFlags(_ a: [String], _ b: [String]) -> ([Bool], [Bool]) {
        let n = a.count, m = b.count
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                dp[i][j] = a[i] == b[j] ? dp[i + 1][j + 1] + 1 : max(dp[i + 1][j], dp[i][j + 1])
            }
        }
        var aFlags = Array(repeating: false, count: n)
        var bFlags = Array(repeating: false, count: m)
        var i = 0, j = 0
        while i < n && j < m {
            if a[i] == b[j] { i += 1; j += 1 }
            else if dp[i + 1][j] >= dp[i][j + 1] { aFlags[i] = true; i += 1 }
            else { bFlags[j] = true; j += 1 }
        }
        while i < n { aFlags[i] = true; i += 1 }
        while j < m { bFlags[j] = true; j += 1 }
        return (aFlags, bFlags)
    }

    private static func lcsLength(_ a: [String], _ b: [String]) -> Int {
        let n = a.count, m = b.count
        guard n > 0 && m > 0 else { return 0 }
        var prev = Array(repeating: 0, count: m + 1)
        var curr = prev
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                curr[j] = a[i] == b[j] ? prev[j + 1] + 1 : max(prev[j], curr[j + 1])
            }
            prev = curr
        }
        return prev[0]
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
