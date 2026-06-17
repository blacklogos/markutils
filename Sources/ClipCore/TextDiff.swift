import Foundation

/// Pure line-level text diff (LCS) — no UI, no WebKit, deterministic, testable,
/// mirroring the ClipCore transform style (`TableTransformer`). Produces a flat
/// unified sequence: unchanged lines as `.equal`, deletions as `.removed`,
/// insertions as `.added`, with removals emitted before additions on a replace
/// (git-style).
///
/// Diff is verbatim and line-based: a trailing newline (which yields a final
/// empty line) shows as a line difference. Whitespace/normalization toggles are
/// deferred (see brainstorm). Callers should bound input size before calling —
/// the LCS table is O(lines_a × lines_b).
public enum TextDiff {

    public enum LineKind: Equatable {
        case equal
        case added
        case removed
    }

    public struct Line: Equatable {
        public let kind: LineKind
        public let text: String
        public init(kind: LineKind, text: String) {
            self.kind = kind
            self.text = text
        }
    }

    public static func diff(_ a: String, _ b: String) -> [Line] {
        let aLines = lines(of: a)
        let bLines = lines(of: b)
        let n = aLines.count, m = bLines.count

        // dp[i][j] = length of the LCS of aLines[i...] and bLines[j...].
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        if n > 0 && m > 0 {
            for i in stride(from: n - 1, through: 0, by: -1) {
                for j in stride(from: m - 1, through: 0, by: -1) {
                    dp[i][j] = aLines[i] == bLines[j]
                        ? dp[i + 1][j + 1] + 1
                        : max(dp[i + 1][j], dp[i][j + 1])
                }
            }
        }

        var result: [Line] = []
        var i = 0, j = 0
        while i < n && j < m {
            if aLines[i] == bLines[j] {
                result.append(Line(kind: .equal, text: aLines[i])); i += 1; j += 1
            } else if dp[i + 1][j] >= dp[i][j + 1] {
                result.append(Line(kind: .removed, text: aLines[i])); i += 1
            } else {
                result.append(Line(kind: .added, text: bLines[j])); j += 1
            }
        }
        while i < n { result.append(Line(kind: .removed, text: aLines[i])); i += 1 }
        while j < m { result.append(Line(kind: .added, text: bLines[j])); j += 1 }
        return result
    }

    /// True when the two texts have no line-level differences.
    public static func isIdentical(_ a: String, _ b: String) -> Bool {
        diff(a, b).allSatisfy { $0.kind == .equal }
    }

    // Empty input → zero lines (so "" vs "x" is a clean single addition, not a
    // spurious removed blank). Otherwise split on newlines, preserving internal
    // and trailing empty lines verbatim.
    private static func lines(of text: String) -> [String] {
        text.isEmpty ? [] : text.components(separatedBy: "\n")
    }
}
