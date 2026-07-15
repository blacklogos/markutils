import XCTest
@testable import Clip
import ClipCore

final class TextDiffTests: XCTestCase {

    private func kinds(_ a: String, _ b: String) -> [TextDiff.LineKind] {
        TextDiff.diff(a, b).map(\.kind)
    }

    func testIdenticalIsAllEqual() {
        XCTAssertEqual(kinds("a\nb", "a\nb"), [.equal, .equal])
    }

    func testAllAddedWhenLeftEmpty() {
        XCTAssertEqual(kinds("", "x\ny"), [.added, .added])
    }

    func testAllRemovedWhenRightEmpty() {
        XCTAssertEqual(kinds("x\ny", ""), [.removed, .removed])
    }

    func testBothEmptyProducesNoLines() {
        XCTAssertTrue(TextDiff.diff("", "").isEmpty)
    }

    func testInsertInMiddle() {
        let d = TextDiff.diff("a\nc", "a\nb\nc")
        XCTAssertEqual(d.map(\.kind), [.equal, .added, .equal])
        XCTAssertEqual(d[1].text, "b")
    }

    func testDeleteInMiddle() {
        XCTAssertEqual(kinds("a\nb\nc", "a\nc"), [.equal, .removed, .equal])
    }

    func testReplaceEmitsRemovedBeforeAdded() {
        let d = TextDiff.diff("a\nOLD\nc", "a\nNEW\nc")
        XCTAssertEqual(d.map(\.kind), [.equal, .removed, .added, .equal])
        XCTAssertEqual(d[1].text, "OLD")
        XCTAssertEqual(d[2].text, "NEW")
    }

    func testReorderKeepsOneCommonLine() {
        let d = TextDiff.diff("a\nb", "b\na")
        XCTAssertEqual(d.filter { $0.kind == .equal }.count, 1)
        XCTAssertTrue(d.contains { $0.kind == .added })
        XCTAssertTrue(d.contains { $0.kind == .removed })
    }

    func testNotIdentical() {
    }
}
