import Foundation

// Side-by-side (split) alignment of an annotated diff: pairs each removed line
// with its replacing added line on one visual row, leaving the opposite cell
// empty (filler) for pure removals/additions. Feeds the Diff tab's two-column view.
public extension TextDiff {

    /// One cell of a split row. `changed == false` → context (equal) line.
    struct SideCell: Equatable {
        public let lineNumber: Int
        public let text: String
        public let segments: [Segment]?
        public let changed: Bool
        public init(lineNumber: Int, text: String, segments: [Segment]?, changed: Bool) {
            self.lineNumber = lineNumber
            self.text = text
            self.segments = segments
            self.changed = changed
        }
    }

    /// One visual row. A nil side renders as a hatched filler cell.
    struct SideRow: Equatable {
        public let left: SideCell?
        public let right: SideCell?
        public init(left: SideCell?, right: SideCell?) {
            self.left = left
            self.right = right
        }
    }

    /// Aligns a unified annotated diff into side-by-side rows with per-side line numbers.
    static func sideBySideRows(_ lines: [AnnotatedLine]) -> [SideRow] {
        var rows: [SideRow] = []
        var leftNo = 0, rightNo = 0
        var idx = 0
        while idx < lines.count {
            let line = lines[idx]
            switch line.kind {
            case .equal:
                leftNo += 1; rightNo += 1
                rows.append(SideRow(
                    left: SideCell(lineNumber: leftNo, text: line.text, segments: nil, changed: false),
                    right: SideCell(lineNumber: rightNo, text: line.text, segments: nil, changed: false)))
                idx += 1
            case .removed:
                // Replace block: removals then the additions that replace them, row-paired.
                var removed: [AnnotatedLine] = []
                while idx < lines.count, lines[idx].kind == .removed { removed.append(lines[idx]); idx += 1 }
                var added: [AnnotatedLine] = []
                while idx < lines.count, lines[idx].kind == .added { added.append(lines[idx]); idx += 1 }
                for k in 0..<max(removed.count, added.count) {
                    var left: SideCell?
                    var right: SideCell?
                    if k < removed.count {
                        leftNo += 1
                        left = SideCell(lineNumber: leftNo, text: removed[k].text,
                                        segments: removed[k].segments, changed: true)
                    }
                    if k < added.count {
                        rightNo += 1
                        right = SideCell(lineNumber: rightNo, text: added[k].text,
                                         segments: added[k].segments, changed: true)
                    }
                    rows.append(SideRow(left: left, right: right))
                }
            case .added:
                // Addition not preceded by a removal (start of text or after equals).
                rightNo += 1
                rows.append(SideRow(
                    left: nil,
                    right: SideCell(lineNumber: rightNo, text: line.text,
                                    segments: line.segments, changed: true)))
                idx += 1
            }
        }
        return rows
    }
}
