import XCTest
@testable import Clip
import ClipCore

final class TextDiffSideBySideTests: XCTestCase {

    private func rows(_ a: String, _ b: String) -> [TextDiff.SideRow] {
        TextDiff.sideBySideRows(TextDiff.annotatedDiff(a, b, precision: .word))
    }

    func testEqualLinesOccupyBothCells() {
        let out = rows("same", "same")
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].left?.text, "same")
        XCTAssertEqual(out[0].right?.text, "same")
        XCTAssertFalse(out[0].left!.changed)
    }

    func testReplacePairsOnOneRow() {
        let out = rows("a b c", "a x c")
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].left?.text, "a b c")
        XCTAssertEqual(out[0].right?.text, "a x c")
        XCTAssertTrue(out[0].left!.changed)
        XCTAssertNotNil(out[0].left?.segments)
    }

    func testPureAdditionLeavesLeftFiller() {
        let out = rows("one", "one\ntwo")
        XCTAssertEqual(out.count, 2)
        XCTAssertNil(out[1].left)
        XCTAssertEqual(out[1].right?.text, "two")
    }

    func testPureRemovalLeavesRightFiller() {
        let out = rows("one\ntwo", "one")
        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(out[1].left?.text, "two")
        XCTAssertNil(out[1].right)
    }

    func testLineNumbersArePerSide() {
        // left: 1,2  right: 1,2,3 (replace row + extra addition)
        let out = rows("keep\nold", "keep\nnew\nextra")
        XCTAssertEqual(out.count, 3)
        XCTAssertEqual(out[0].left?.lineNumber, 1)
        XCTAssertEqual(out[0].right?.lineNumber, 1)
        XCTAssertEqual(out[1].left?.lineNumber, 2)   // "old"
        XCTAssertEqual(out[1].right?.lineNumber, 2)  // "new"
        XCTAssertNil(out[2].left)
        XCTAssertEqual(out[2].right?.lineNumber, 3)  // "extra"
    }

    func testUnevenReplaceBlockFillsShorterSide() {
        // 2 removed vs 1 added → second row has right filler
        let out = rows("a\nb", "x")
        XCTAssertEqual(out.count, 2)
        XCTAssertNotNil(out[0].left)
        XCTAssertNotNil(out[0].right)
        XCTAssertNotNil(out[1].left)
        XCTAssertNil(out[1].right)
    }
}
