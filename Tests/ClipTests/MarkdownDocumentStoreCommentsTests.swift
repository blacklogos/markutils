import XCTest
import AppKit
@testable import Clip
import ClipCore

// Comment-awareness wired into the document store: sidecar load on open, and the
// re-anchor pass on every content change (open + live reload). The copy actions'
// payloads are exercised through the same compiler calls the header buttons make.
final class MarkdownDocumentStoreCommentsTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MDSCommentsTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func makeStore() -> (MarkdownDocumentStore, CommentStore) {
        let cs = CommentStore(directory: tempDir.appendingPathComponent("comments"))
        return (MarkdownDocumentStore(commentStore: cs), cs)
    }

    private func write(_ body: String, _ name: String) -> URL {
        let url = tempDir.appendingPathComponent(name)
        try! body.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Sidecar load on open

    func testOpeningFileLoadsItsCommentsAndSwitchingSwaps() {
        let (store, cs) = makeStore()
        let fileA = write("# A\n\nThe price is $9 per month.\n", "a.md")
        store.openFile(fileA)
        XCTAssertTrue(cs.comments.isEmpty)
        cs.addComment(quote: "$9 per month", prefix: "price is ", suffix: ".", note: "punchier")

        let fileB = write("# B\n\nUnrelated content.\n", "b.md")
        store.openFile(fileB)
        XCTAssertTrue(cs.comments.isEmpty, "Different file must not show A's comments")

        store.openFile(fileA)
        XCTAssertEqual(cs.comments.count, 1, "Re-opening A restores its sidecar")
    }

    // MARK: - Re-anchor on reload (AE3 / AE4)

    func testReloadWithQuoteIntactKeepsCommentActive() {
        let (store, cs) = makeStore()
        let file = write("# Doc\n\nThe price is $9 per month.\n", "doc.md")
        store.openFile(file)
        cs.addComment(quote: "$9 per month", prefix: "price is ", suffix: ".", note: "punchier")

        _ = write("# Doc edited\n\nThe price is $9 per month, still.\n", "doc.md")
        store.openFile(file)   // simulates the live-reload funnel

        XCTAssertEqual(cs.comments.count, 1)
        XCTAssertEqual(cs.comments.first?.status, .active)
    }

    func testReloadWithQuoteGoneFlagsNeedsReviewAndRetains() {
        let (store, cs) = makeStore()
        let file = write("# Doc\n\nThe price is $9 per month.\n", "doc.md")
        store.openFile(file)
        cs.addComment(quote: "$9 per month", prefix: "price is ", suffix: ".", note: "punchier")

        _ = write("# Doc\n\nNo pricing mentioned anymore.\n", "doc.md")
        store.openFile(file)

        XCTAssertEqual(cs.comments.count, 1, "Orphaned comment must be retained, not deleted")
        XCTAssertEqual(cs.comments.first?.status, .needsReview)
    }

    func testReanchorNeverReducesCommentCount() {
        let (store, cs) = makeStore()
        let file = write("# Doc\n\nAlpha and beta and gamma.\n", "doc.md")
        store.openFile(file)
        cs.addComment(quote: "Alpha", prefix: "", suffix: "", note: "1")
        cs.addComment(quote: "gamma", prefix: "", suffix: "", note: "2")

        _ = write("# Doc\n\nCompletely different text now.\n", "doc.md")
        store.openFile(file)
        XCTAssertEqual(cs.comments.count, 2, "No silent deletion on re-anchor")
    }

    // MARK: - Copy action payloads

    func testCopyWholeFilePlacesCompilerOutputOnPasteboard() {
        let (store, cs) = makeStore()
        let file = write("# Doc\n\nThe price is $9 per month.\n", "doc.md")
        store.openFile(file)
        cs.addComment(quote: "$9 per month", prefix: "price is ", suffix: ".", note: "punchier")

        // Same call the "Copy whole file" header button makes.
        Pasteboard.copy(CommentInstructionCompiler.wholeFile(comments: cs.comments, in: store.fileContent))
        let pasted = NSPasteboard.general.string(forType: .string)
        XCTAssertNotNil(pasted)
        XCTAssertTrue(pasted!.contains(#"💬 INSTRUCTION (on "$9 per month"): punchier"#))
    }

    func testCopySectionPlacesSectionOutputOnPasteboard() {
        let (store, cs) = makeStore()
        let file = write("# Doc\n\nThe price is $9 per month.\n", "doc.md")
        store.openFile(file)
        let comment = cs.addComment(quote: "$9 per month", prefix: "price is ",
                                    suffix: ".", note: "punchier")!

        Pasteboard.copy(CommentInstructionCompiler.section(for: comment, in: store.fileContent))
        let pasted = NSPasteboard.general.string(forType: .string)
        XCTAssertNotNil(pasted)
        XCTAssertTrue(pasted!.contains("The price is $9 per month."))
        XCTAssertTrue(pasted!.contains("💬 INSTRUCTION"))
    }
}
