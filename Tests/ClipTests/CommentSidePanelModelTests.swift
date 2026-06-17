import XCTest
@testable import Clip
import ClipCore

// The side panel and capture popover are thin SwiftUI over CommentStore; the
// save/edit/delete logic (and its empty-note guard) lives in the store and is
// tested here. Popover placement and scroll-flash are verified manually (UI).
final class CommentSidePanelModelTests: XCTestCase {

    private var tempDir: URL!
    private var file: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PanelTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        file = tempDir.appendingPathComponent("doc.md")
        try "# Doc\n\nThe price is $9 per month.\n".write(to: file, atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func loadedStore() -> CommentStore {
        let store = CommentStore(directory: tempDir.appendingPathComponent("comments"))
        store.load(for: file)
        return store
    }

    func testSavingNoteCreatesExactlyOneEntry() {
        let store = loadedStore()
        let created = store.addComment(quote: "$9 per month", prefix: "price is ",
                                       suffix: ".", note: "make this punchier")
        XCTAssertNotNil(created)
        XCTAssertEqual(store.comments.count, 1)
        XCTAssertEqual(store.comments.first?.quote, "$9 per month")
        XCTAssertEqual(store.comments.first?.note, "make this punchier")
    }

    func testEmptyNoteIsRejectedAndNothingPersisted() {
        let store = loadedStore()
        XCTAssertNil(store.addComment(quote: "$9 per month", prefix: "", suffix: "", note: "   "))
        XCTAssertTrue(store.comments.isEmpty)

        let reloaded = CommentStore(directory: tempDir.appendingPathComponent("comments"))
        reloaded.load(for: file)
        XCTAssertTrue(reloaded.comments.isEmpty)
    }

    func testEditingNoteUpdatesAndPersists() {
        let store = loadedStore()
        let c = store.addComment(quote: "$9 per month", prefix: "", suffix: "", note: "first")!
        store.updateNote(id: c.id, note: "second")

        let reloaded = CommentStore(directory: tempDir.appendingPathComponent("comments"))
        reloaded.load(for: file)
        XCTAssertEqual(reloaded.comments.first?.note, "second")
    }

    func testBlankEditIsIgnored() {
        let store = loadedStore()
        let c = store.addComment(quote: "$9 per month", prefix: "", suffix: "", note: "keep me")!
        store.updateNote(id: c.id, note: "   ")
        XCTAssertEqual(store.comments.first?.note, "keep me")
    }

    func testClearAllRemovesEveryCommentAndPersists() {
        let store = loadedStore()
        store.addComment(quote: "$9 per month", prefix: "", suffix: "", note: "a")
        store.addComment(quote: "Doc", prefix: "", suffix: "", note: "b")
        XCTAssertEqual(store.comments.count, 2)
        store.clearAll()
        XCTAssertTrue(store.comments.isEmpty)

        let reloaded = CommentStore(directory: tempDir.appendingPathComponent("comments"))
        reloaded.load(for: file)
        XCTAssertTrue(reloaded.comments.isEmpty)
    }

    func testDeletingRemovesCommentAndPersists() {
        let store = loadedStore()
        let c = store.addComment(quote: "$9 per month", prefix: "", suffix: "", note: "doomed")!
        store.delete(c)

        let reloaded = CommentStore(directory: tempDir.appendingPathComponent("comments"))
        reloaded.load(for: file)
        XCTAssertTrue(reloaded.comments.isEmpty)
    }
}
