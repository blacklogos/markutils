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
        let (aFlags, bFlags) = lcsFlags(aLines, bLines)

        // Replay the flag walk: unflagged pairs are equal, flagged entries emit
        // removed/added in the same order the LCS walk decided them.
        var result: [Line] = []
        var i = 0, j = 0
        while i < aLines.count && j < bLines.count {
            if !aFlags[i] && !bFlags[j] {
                result.append(Line(kind: .equal, text: aLines[i])); i += 1; j += 1
            } else if aFlags[i] {
                result.append(Line(kind: .removed, text: aLines[i])); i += 1
            } else {
                result.append(Line(kind: .added, text: bLines[j])); j += 1
            }
        }
        while i < aLines.count { result.append(Line(kind: .removed, text: aLines[i])); i += 1 }
        while j < bLines.count { result.append(Line(kind: .added, text: bLines[j])); j += 1 }
        return result
    }

    /// Number of lines `diff` operates on ("" → 0; else newline count + 1).
    /// Matches `lines(of:)` semantics without allocating the line array.
    public static func lineCount(_ text: String) -> Int {
        text.isEmpty ? 0 : text.reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
    }

    // MARK: - Shared LCS engine

    /// The single LCS implementation for the whole diff engine (lines and
    /// intra-line tokens). Flat DP buffer; marks elements outside the common
    /// subsequence as true. Tie-break prefers advancing the left side, which
    /// makes removals precede additions in replace blocks (git-style).
    static func lcsFlags<T: Equatable>(_ a: [T], _ b: [T]) -> ([Bool], [Bool]) {
        let n = a.count, m = b.count
        let width = m + 1
        var dp = [Int](repeating: 0, count: (n + 1) * width)
        if n > 0 && m > 0 {
            for i in (0..<n).reversed() {
                for j in (0..<m).reversed() {
                    dp[i * width + j] = a[i] == b[j]
                        ? dp[(i + 1) * width + j + 1] + 1
                        : max(dp[(i + 1) * width + j], dp[i * width + j + 1])
                }
            }
        }
        var aFlags = [Bool](repeating: false, count: n)
        var bFlags = [Bool](repeating: false, count: m)
        var i = 0, j = 0
        while i < n && j < m {
            if a[i] == b[j] { i += 1; j += 1 }
            else if dp[(i + 1) * width + j] >= dp[i * width + j + 1] { aFlags[i] = true; i += 1 }
            else { bFlags[j] = true; j += 1 }
        }
        while i < n { aFlags[i] = true; i += 1 }
        while j < m { bFlags[j] = true; j += 1 }
        return (aFlags, bFlags)
    }

    // Empty input → zero lines (so "" vs "x" is a clean single addition, not a
    // spurious removed blank). Otherwise split on newlines, preserving internal
    // and trailing empty lines verbatim.
    private static func lines(of text: String) -> [String] {
        text.isEmpty ? [] : text.components(separatedBy: "\n")
    }
}
