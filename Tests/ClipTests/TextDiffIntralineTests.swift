import XCTest
@testable import Clip
import ClipCore

final class TextDiffIntralineTests: XCTestCase {

    private func changedTexts(_ segments: [TextDiff.Segment]?) -> [String] {
        (segments ?? []).filter(\.changed).map(\.text)
    }

    // MARK: - Line precision (old behavior)

    func testLinePrecisionHasNoSegments() {
        let out = TextDiff.annotatedDiff("hello world", "hello there", precision: .line)
        XCTAssertTrue(out.allSatisfy { $0.segments == nil })
        XCTAssertEqual(out.map(\.kind), [.removed, .added])
    }

    // MARK: - Word precision

    func testWordPrecisionMarksOnlyChangedWord() {
        let out = TextDiff.annotatedDiff("the quick brown fox", "the quick red fox", precision: .word)
        XCTAssertEqual(changedTexts(out[0].segments), ["brown"])
        XCTAssertEqual(changedTexts(out[1].segments), ["red"])
    }

    func testWordPrecisionSegmentsReassembleLine() {
        let out = TextDiff.annotatedDiff("a b c", "a x c", precision: .word)
        for line in out where line.segments != nil {
            XCTAssertEqual(line.segments!.map(\.text).joined(), line.text)
        }
    }

    // MARK: - Character precision

    func testCharacterPrecisionMarksSingleCharEdit() {
        let out = TextDiff.annotatedDiff("kitten", "sitten", precision: .character)
        XCTAssertEqual(changedTexts(out[0].segments), ["k"])
        XCTAssertEqual(changedTexts(out[1].segments), ["s"])
    }

    // MARK: - Smart precision

    func testSmartUsesCharacterForTypoLevelEdit() {
        // One char differs in a short line → char-level highlight
        let out = TextDiff.annotatedDiff("the quick brown fox", "the quick browm fox", precision: .smart)
        let changed = changedTexts(out[0].segments)
        XCTAssertEqual(changed, ["n"])
    }

    func testSmartFallsBackToWholeLineWhenMostlyDifferent() {
        let out = TextDiff.annotatedDiff("alpha beta gamma", "one two three four five six", precision: .smart)
        XCTAssertTrue(out.allSatisfy { $0.segments == nil })
    }

    func testSmartUsesWordForPartialOverlap() {
        let out = TextDiff.annotatedDiff(
            "the quick brown fox jumps over the lazy dog",
            "the quick red fox leaps over the lazy dog", precision: .smart)
        XCTAssertEqual(changedTexts(out[0].segments), ["brown", "jumps"])
        XCTAssertEqual(changedTexts(out[1].segments), ["red", "leaps"])
    }

    // MARK: - Block pairing

    func testUnpairedLinesStayWholeLine() {
        // 1 removed, 2 added: first added pairs, second stays whole-line
        let out = TextDiff.annotatedDiff("a b c", "a x c\nnew line", precision: .word)
        XCTAssertEqual(out.map(\.kind), [.removed, .added, .added])
        XCTAssertNotNil(out[0].segments)
        XCTAssertNotNil(out[1].segments)
        XCTAssertNil(out[2].segments)
    }

    func testEqualLinesHaveNoSegments() {
        let out = TextDiff.annotatedDiff("same\nchanged a", "same\nchanged b", precision: .word)
        XCTAssertEqual(out[0].kind, .equal)
        XCTAssertNil(out[0].segments)
    }

    func testPureAdditionHasNoSegments() {
        let out = TextDiff.annotatedDiff("", "brand new", precision: .word)
        XCTAssertEqual(out.map(\.kind), [.added])
        XCTAssertNil(out[0].segments)
    }

    // MARK: - Vietnamese / multi-byte safety

    func testWordPrecisionWithVietnamese() {
        let out = TextDiff.annotatedDiff("xin chào thế giới", "xin chào các bạn", precision: .word)
        XCTAssertEqual(changedTexts(out[0].segments), ["thế", "giới"])
        XCTAssertEqual(changedTexts(out[1].segments), ["các", "bạn"])
    }
}
