import XCTest
@testable import Clip
import ClipCore

final class CommentStoreTests: XCTestCase {

    private var tempDir: URL!
    private var commentsDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CommentStoreTests-\(UUID().uuidString)")
        commentsDir = tempDir.appendingPathComponent("comments")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // A real markdown file on disk so we can assert its bytes never change.
    private func makeSourceFile(_ body: String = "# Doc\n\nHello world.\n") throws -> URL {
        let url = tempDir.appendingPathComponent("doc-\(UUID().uuidString).md")
        try body.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Round-trip

    func testAddThenReloadReturnsEqualComment() throws {
        let file = try makeSourceFile()
        let store = CommentStore(directory: commentsDir)
        store.load(for: file)

        let comment = Comment(quote: "Hello world", prefix: "", suffix: ".",
                              note: "make this punchier")
        store.add(comment)

        // Fresh store reading the same sidecar must reconstruct an equal comment.
        let reloaded = CommentStore(directory: commentsDir)
        reloaded.load(for: file)

        XCTAssertEqual(reloaded.comments.count, 1)
        XCTAssertEqual(reloaded.comments.first, comment)
    }

    // MARK: - Per-file isolation

    func testTwoFilesPersistToSeparateSidecars() throws {
        let fileA = try makeSourceFile()
        let fileB = try makeSourceFile()

        let store = CommentStore(directory: commentsDir)
        store.load(for: fileA)
        store.add(Comment(quote: "A-quote", note: "note A"))

        store.load(for: fileB)
        XCTAssertTrue(store.comments.isEmpty, "Switching files must not bleed comments")
        store.add(Comment(quote: "B-quote", note: "note B"))

        let reA = CommentStore(directory: commentsDir); reA.load(for: fileA)
        let reB = CommentStore(directory: commentsDir); reB.load(for: fileB)
        XCTAssertEqual(reA.comments.map(\.quote), ["A-quote"])
        XCTAssertEqual(reB.comments.map(\.quote), ["B-quote"])
    }

    func testDistinctFilesHaveDistinctKeys() throws {
        let fileA = try makeSourceFile()
        let fileB = try makeSourceFile()
        XCTAssertNotEqual(CommentStore.key(for: fileA), CommentStore.key(for: fileB))
    }

    // MARK: - Empty / missing sidecar

    func testLoadingFileWithNoSidecarYieldsEmptyListNoError() throws {
        let file = try makeSourceFile()
        let store = CommentStore(directory: commentsDir)
        store.load(for: file)
        XCTAssertTrue(store.comments.isEmpty)
    }

    // MARK: - Delete

    func testDeleteRemovesCommentOnNextLoad() throws {
        let file = try makeSourceFile()
        let store = CommentStore(directory: commentsDir)
        store.load(for: file)
        let c = Comment(quote: "doomed", note: "to be removed")
        store.add(c)
        store.delete(c)

        let reloaded = CommentStore(directory: commentsDir)
        reloaded.load(for: file)
        XCTAssertTrue(reloaded.comments.isEmpty)
    }

    // MARK: - Status round-trip

    func testStatusRoundTrips() throws {
        let file = try makeSourceFile()
        let store = CommentStore(directory: commentsDir)
        store.load(for: file)
        store.add(Comment(quote: "active one", note: "n1", status: .active))
        store.add(Comment(quote: "orphan one", note: "n2", status: .needsReview))

        let reloaded = CommentStore(directory: commentsDir)
        reloaded.load(for: file)
        let byNote = Dictionary(uniqueKeysWithValues: reloaded.comments.map { ($0.note, $0.status) })
        XCTAssertEqual(byNote["n1"], .active)
        XCTAssertEqual(byNote["n2"], .needsReview)
    }

    // MARK: - Source safety (R11)

    func testSourceFileBytesUnchangedAfterAddEditDelete() throws {
        let body = "# Doc\n\nThe price is $9 per month.\n"
        let file = try makeSourceFile(body)
        let before = try Data(contentsOf: file)
        let beforeMtime = try FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date

        let store = CommentStore(directory: commentsDir)
        store.load(for: file)
        var c = Comment(quote: "$9 per month", note: "make punchier")
        store.add(c)
        c.note = "make it bolder"
        store.update(c)
        store.delete(c)

        let after = try Data(contentsOf: file)
        let afterMtime = try FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date
        XCTAssertEqual(before, after, "Source .md bytes must be untouched")
        XCTAssertEqual(beforeMtime, afterMtime, "Source .md mtime must be untouched")
    }
}
