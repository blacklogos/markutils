import XCTest
@testable import Clip

final class MarkdownReaderTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MarkdownReaderTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func makeFile(_ relativePath: String, contents: String = "# Hi") throws -> URL {
        let url = tempDir.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - File type detection

    func testMarkdownExtensionsRecognized() {
        XCTAssertTrue(MarkdownDocumentStore.isMarkdownFile(URL(fileURLWithPath: "/a/readme.md")))
        XCTAssertTrue(MarkdownDocumentStore.isMarkdownFile(URL(fileURLWithPath: "/a/README.MD")))
        XCTAssertTrue(MarkdownDocumentStore.isMarkdownFile(URL(fileURLWithPath: "/a/notes.markdown")))
        XCTAssertTrue(MarkdownDocumentStore.isMarkdownFile(URL(fileURLWithPath: "/a/plain.txt")))
        XCTAssertFalse(MarkdownDocumentStore.isMarkdownFile(URL(fileURLWithPath: "/a/image.png")))
        XCTAssertFalse(MarkdownDocumentStore.isMarkdownFile(URL(fileURLWithPath: "/a/binary")))
    }

    // MARK: - Folder scanning

    func testScanFindsMarkdownFilesRecursively() throws {
        try makeFile("root.md")
        try makeFile("sub/nested.md")
        try makeFile("sub/deeper/deep.markdown")
        try makeFile("sub/skipped.png", contents: "not md")

        let tree = MarkdownDocumentStore.scanFolder(tempDir)

        XCTAssertEqual(MarkdownDocumentStore.fileCount(in: tree), 3)
        // Folders sort before files
        XCTAssertEqual(tree.first?.name, "sub")
        XCTAssertTrue(tree.first?.isDirectory ?? false)
        XCTAssertEqual(tree.last?.name, "root.md")
    }

    func testScanPrunesFoldersWithoutMarkdown() throws {
        try makeFile("docs/guide.md")
        try makeFile("assets/logo.png", contents: "binary")

        let tree = MarkdownDocumentStore.scanFolder(tempDir)

        XCTAssertEqual(tree.count, 1)
        XCTAssertEqual(tree.first?.name, "docs")
    }

    func testScanSkipsHiddenFiles() throws {
        try makeFile(".hidden.md")
        try makeFile(".git/objects/notes.md")
        try makeFile("visible.md")

        let tree = MarkdownDocumentStore.scanFolder(tempDir)

        XCTAssertEqual(MarkdownDocumentStore.fileCount(in: tree), 1)
        XCTAssertEqual(tree.first?.name, "visible.md")
    }

    func testScanSortsFoldersFirstThenAlphabetically() throws {
        try makeFile("zebra.md")
        try makeFile("alpha.md")
        try makeFile("beta/inner.md")

        let tree = MarkdownDocumentStore.scanFolder(tempDir)

        XCTAssertEqual(tree.map(\.name), ["beta", "alpha.md", "zebra.md"])
    }

    func testFirstFileFindsNestedFile() throws {
        try makeFile("a/b/only.md")

        let tree = MarkdownDocumentStore.scanFolder(tempDir)
        let first = MarkdownDocumentStore.firstFile(in: tree)

        XCTAssertEqual(first?.name, "only.md")
    }

    // MARK: - Opening documents

    func testOpenFileLoadsContent() throws {
        let url = try makeFile("doc.md", contents: "# Title\n\nBody text")
        let store = MarkdownDocumentStore()

        XCTAssertTrue(store.open(url: url))
        XCTAssertEqual(store.currentFileURL, url)
        XCTAssertEqual(store.fileContent, "# Title\n\nBody text")
        XCTAssertNil(store.loadError)
    }

    func testOpenFolderBuildsTreeAndSelectsFirstFile() throws {
        try makeFile("notes/a.md", contents: "# A")
        try makeFile("notes/b.md", contents: "# B")
        let store = MarkdownDocumentStore()

        XCTAssertTrue(store.openFolder(tempDir, synchronous: true))
        XCTAssertEqual(store.rootFolderURL, tempDir)
        XCTAssertEqual(store.fileCount, 2)
        // First file auto-selected so the preview is never empty
        XCTAssertEqual(store.currentFileURL?.lastPathComponent, "a.md")
        XCTAssertEqual(store.fileContent, "# A")
        XCTAssertTrue(store.renderedHTML.contains("<h1"), "HTML is rendered once per content change")
    }

    func testOpenEmptyFolderFails() throws {
        let store = MarkdownDocumentStore()

        XCTAssertFalse(store.openFolder(tempDir, synchronous: true))
        XCTAssertNotNil(store.loadError)
        XCTAssertNil(store.rootFolderURL)
    }

    func testOpenMissingFileFails() {
        let store = MarkdownDocumentStore()
        let missing = tempDir.appendingPathComponent("nope.md")

        XCTAssertFalse(store.open(url: missing))
        XCTAssertNotNil(store.loadError)
    }

    func testOpenRejectsNonMarkdownFile() throws {
        let binary = tempDir.appendingPathComponent("image.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: binary)
        let store = MarkdownDocumentStore()

        XCTAssertFalse(store.open(url: binary))
        XCTAssertNotNil(store.loadError)
        XCTAssertNil(store.currentFileURL)
    }

    func testOpenFileOutsideTreeExitsFolderMode() throws {
        try makeFile("inside/a.md")
        let outside = try makeFile("outside.md", contents: "# Outside")
        let store = MarkdownDocumentStore()

        let insideFolder = tempDir.appendingPathComponent("inside")
        XCTAssertTrue(store.openFolder(insideFolder, synchronous: true))
        XCTAssertNotNil(store.rootFolderURL)

        XCTAssertTrue(store.openFile(outside))
        XCTAssertNil(store.rootFolderURL, "Opening a file outside the tree should exit folder mode")
        XCTAssertTrue(store.fileTree.isEmpty)
    }

    func testAsyncFolderOpenPublishesTreeOnMain() throws {
        try makeFile("docs/a.md", contents: "# A")
        let store = MarkdownDocumentStore()

        XCTAssertTrue(store.open(url: tempDir), "Folders are accepted optimistically")
        XCTAssertTrue(store.isScanning)

        let deadline = Date().addingTimeInterval(5)
        while store.isScanning && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertFalse(store.isScanning)
        XCTAssertEqual(store.fileCount, 1)
        XCTAssertEqual(store.currentFileURL?.lastPathComponent, "a.md")
    }

    func testExternalOpenBumpsCounter() throws {
        let url = try makeFile("doc.md")
        let store = MarkdownDocumentStore()

        let before = store.externalOpenCount
        store.open(url: url, external: true)
        XCTAssertEqual(store.externalOpenCount, before + 1)

        // Internal opens (sidebar clicks) must not re-trigger tab switching
        store.open(url: url, external: false)
        XCTAssertEqual(store.externalOpenCount, before + 1)
    }

    func testCloseAllResetsState() throws {
        let url = try makeFile("doc.md")
        let store = MarkdownDocumentStore()
        store.open(url: url)

        store.closeAll()

        XCTAssertNil(store.currentFileURL)
        XCTAssertEqual(store.fileContent, "")
        XCTAssertNil(store.rootFolderURL)
        XCTAssertTrue(store.fileTree.isEmpty)
    }

    func testRecentsAreDedupedAndCapped() throws {
        let store = MarkdownDocumentStore()
        var urls: [URL] = []
        for i in 0..<8 {
            urls.append(try makeFile("doc\(i).md"))
        }
        for url in urls { store.open(url: url) }
        // Re-open the first one — it should move to the front, not duplicate
        store.open(url: urls[0])

        XCTAssertEqual(store.recentURLs.first, urls[0])
        XCTAssertLessThanOrEqual(store.recentURLs.count, 6)
        XCTAssertEqual(Set(store.recentURLs).count, store.recentURLs.count)
    }
}
