import XCTest
@testable import Clip
import ClipCore

final class CommentAnchorTests: XCTestCase {

    // MARK: - Re-anchor (AE3 / AE4)

    func testReanchorStaysActiveWhenQuoteSurvivesUnrelatedEdit() {
        let comment = Comment(quote: "this sentence", note: "tighten")
        let edited = "Totally unrelated edit, but keep this sentence intact still.\n"
        XCTAssertEqual(CommentAnchor.reanchor(comment, in: edited).status, .active)
    }

    func testReanchorFlagsNeedsReviewWhenQuoteDeleted() {
        let comment = Comment(quote: "this sentence", note: "tighten")
        let rewritten = "The line is completely rewritten now.\n"
        let result = CommentAnchor.reanchor(comment, in: rewritten)
        XCTAssertEqual(result.status, .needsReview)
        XCTAssertEqual(result.id, comment.id, "Re-anchor must retain, never replace/drop the comment")
    }

    // MARK: - Disambiguation

    func testDuplicateQuoteResolvesByContext() {
        let text = "The base rate is fixed.\n\nThe premium rate is higher.\n"
        let base = CommentAnchor.locate(quote: "rate", prefix: "base ", suffix: " is fixed", in: text)
        let premium = CommentAnchor.locate(quote: "rate", prefix: "premium ", suffix: " is higher", in: text)
        XCTAssertNotNil(base)
        XCTAssertNotNil(premium)
        XCTAssertNotEqual(base!.lowerBound, premium!.lowerBound)
        let allRates = Array(text.ranges(of: "rate"))
        XCTAssertEqual(base!.lowerBound, allRates.first!.lowerBound)
        XCTAssertEqual(premium!.lowerBound, allRates.last!.lowerBound)
    }

    func testDuplicateQuoteWithoutContextFallsBackToFirstOccurrence() {
        let text = "The base rate is fixed.\n\nThe premium rate is higher.\n"
        let located = CommentAnchor.locate(quote: "rate", in: text)
        XCTAssertEqual(located?.lowerBound, text.range(of: "rate")!.lowerBound)
    }

    // MARK: - Enclosing block

    func testEnclosingBlockReturnsFullParagraphForMidParagraphPhrase() {
        let doc = "# Title\n\nThe plan costs $9 per month and renews yearly.\nLine two of para.\n\nNext para.\n"
        let range = CommentAnchor.locate(quote: "$9 per month", in: doc)!
        XCTAssertEqual(CommentAnchor.enclosingBlock(of: range, in: doc),
                       "The plan costs $9 per month and renews yearly.\nLine two of para.")
    }

    func testEnclosingBlockReturnsHeadingLineForHeadingSpan() {
        let doc = "# Title\n\nBody text here.\n"
        let range = CommentAnchor.locate(quote: "Title", in: doc)!
        XCTAssertEqual(CommentAnchor.enclosingBlock(of: range, in: doc), "# Title")
    }

    func testEnclosingBlockReturnsSingleListItem() {
        let listDoc = "Intro para.\n\n- first item here\n- second item there\n- third\n"
        let range = CommentAnchor.locate(quote: "second item", in: listDoc)!
        XCTAssertEqual(CommentAnchor.enclosingBlock(of: range, in: listDoc), "- second item there")
    }

    func testEnclosingBlockReturnsSingleOrderedListItem() {
        let olDoc = "1. alpha\n2. beta value\n3. gamma\n"
        let range = CommentAnchor.locate(quote: "beta value", in: olDoc)!
        XCTAssertEqual(CommentAnchor.enclosingBlock(of: range, in: olDoc), "2. beta value")
    }

    // MARK: - Empty / missing

    func testEmptyQuoteAndEmptySourceReturnNil() {
        XCTAssertNil(CommentAnchor.locate(quote: "", in: "some text"))
        XCTAssertNil(CommentAnchor.locate(quote: "x", in: ""))
        XCTAssertNil(CommentAnchor.enclosingBlock(forQuote: "absent", in: "some text"))
    }
}
