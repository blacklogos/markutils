import XCTest
@testable import Clip
import ClipCore

final class CommentInstructionCompilerTests: XCTestCase {

    private let doc = "# Pricing\n\nThe plan costs $9 per month and renews yearly.\n\nThanks for reading.\n"

    // MARK: - Section (AE2)

    func testSectionContainsPreambleBlockAndCallout() {
        let comment = Comment(quote: "$9 per month", note: "make this punchier")
        let section = CommentInstructionCompiler.section(for: comment, in: doc)
        XCTAssertTrue(section.contains(CommentInstructionCompiler.preamble))
        XCTAssertTrue(section.contains("The plan costs $9 per month and renews yearly."))
        XCTAssertTrue(section.contains(#"💬 INSTRUCTION (on "$9 per month"): make this punchier"#))
    }

    // MARK: - Whole file

    func testWholeFilePreservesSourceExceptCalloutLines() {
        let comment = Comment(quote: "$9 per month", note: "punchier")
        let output = CommentInstructionCompiler.wholeFile(comments: [comment], in: doc)
        let body = String(output.dropFirst(CommentInstructionCompiler.preamble.count + 2))
        let withoutCallouts = body
            .components(separatedBy: "\n")
            .filter { !$0.hasPrefix("💬") }
            .joined(separator: "\n")
        XCTAssertEqual(withoutCallouts, doc)
    }

    func testWholeFileZeroCommentsReturnsPreamblePlusUnchangedSource() {
        let output = CommentInstructionCompiler.wholeFile(comments: [], in: doc)
        XCTAssertEqual(output, CommentInstructionCompiler.preamble + "\n\n" + doc)
    }

    // MARK: - Orphans (AE4)

    func testOrphanedCommentAppendedNotInlinedAndNotDropped() {
        let active = Comment(quote: "$9 per month", note: "punchier")
        let orphan = Comment(quote: "deleted text", note: "fix me", status: .needsReview)
        let output = CommentInstructionCompiler.wholeFile(comments: [active, orphan], in: doc)

        XCTAssertTrue(output.contains("Notes that no longer match the text:"))
        XCTAssertTrue(output.contains(#"💬 INSTRUCTION (on "deleted text"): fix me"#))

        let header = output.range(of: "Notes that no longer match")!.lowerBound
        let orphanCallout = output.range(of: "deleted text")!.lowerBound
        XCTAssertGreaterThan(orphanCallout, header, "Orphan must be in the appendix, not inline")
    }

    // MARK: - Ordering & safety

    func testMultipleCommentsEmitInDocumentOrder() {
        let multiDoc = "Alpha line one.\n\nBravo line two.\n\nCharlie line three.\n"
        let c1 = Comment(quote: "Charlie", note: "third")
        let c2 = Comment(quote: "Alpha", note: "first")
        let c3 = Comment(quote: "Bravo", note: "second")
        let output = CommentInstructionCompiler.wholeFile(comments: [c1, c2, c3], in: multiDoc)
        let first = output.range(of: ": first")!.lowerBound
        let second = output.range(of: ": second")!.lowerBound
        let third = output.range(of: ": third")!.lowerBound
        XCTAssertTrue(first < second && second < third)
    }

    func testNoteWithMarkdownCharactersDoesNotCorruptBlockStructure() {
        let multiDoc = "Alpha line one.\n\nBravo line two.\n"
        let comment = Comment(quote: "Alpha", note: "# not a heading\n- not a list")
        let output = CommentInstructionCompiler.wholeFile(comments: [comment], in: multiDoc)
        let calloutLine = output.components(separatedBy: "\n").first { $0.hasPrefix("💬") }
        XCTAssertNotNil(calloutLine)
        XCTAssertTrue(calloutLine!.contains("# not a heading - not a list"),
                      "Multi-line note must be flattened onto the single callout line")
    }
}
