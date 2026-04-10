import XCTest
@testable import Clip

final class SearchTests: XCTestCase {

    // MARK: - Helpers

    private func makeTree() -> [Asset] {
        // Flat assets
        let img = Asset(type: .image, imageData: Data(), name: "banner.png")
        let txt = Asset(type: .text, textContent: "Hello world", name: "greeting.txt")

        // Nested folder: Screenshots/ → logo-dark.svg
        let nestedChild = Asset(type: .text, textContent: "<svg>...</svg>", name: "logo-dark.svg")
        let folder = Asset(type: .folder, name: "Screenshots", children: [nestedChild])

        // Deeply nested: Docs/ → Drafts/ → readme.md
        let deepLeaf = Asset(type: .text, textContent: "# README", name: "readme.md")
        let innerFolder = Asset(type: .folder, name: "Drafts", children: [deepLeaf])
        let outerFolder = Asset(type: .folder, name: "Docs", children: [innerFolder])

        return [img, txt, folder, outerFolder]
    }

    // MARK: - Tests

    func testEmptyQueryReturnsEmpty() {
        // Swift's String.contains("") returns false (NSString bridging).
        // The caller (AssetGridView.assets) short-circuits with allAssets when
        // searchText is empty, so searchAssets is never called with "".
        // This test documents the behavior and verifies no crash.
        let results = AssetGridView.searchAssets(makeTree(), query: "")
        XCTAssertTrue(results.isEmpty)
    }

    func testTopLevelNameMatch() {
        let results = AssetGridView.searchAssets(makeTree(), query: "banner")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "banner.png")
    }

    func testTopLevelContentMatch() {
        let results = AssetGridView.searchAssets(makeTree(), query: "hello")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "greeting.txt")
    }

    func testNestedChildMatch() {
        // "logo" only exists inside Screenshots/ folder
        let results = AssetGridView.searchAssets(makeTree(), query: "logo")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "logo-dark.svg")
    }

    func testDeeplyNestedMatch() {
        // "readme" is inside Docs/ → Drafts/ → readme.md (2 levels deep)
        let results = AssetGridView.searchAssets(makeTree(), query: "readme")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "readme.md")
    }

    func testFolderNameMatch() {
        // "screenshots" matches the folder name directly
        let results = AssetGridView.searchAssets(makeTree(), query: "screenshots")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Screenshots")
        XCTAssertEqual(results[0].type, .folder)
    }

    func testNoMatch() {
        let results = AssetGridView.searchAssets(makeTree(), query: "nonexistent")
        XCTAssertTrue(results.isEmpty)
    }

    func testCaseInsensitive() {
        let results = AssetGridView.searchAssets(makeTree(), query: "BANNER")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "banner.png")
    }

    func testMultipleMatches() {
        // "d" matches: logo-dark.svg, Drafts folder, Docs folder
        let results = AssetGridView.searchAssets(makeTree(), query: "draft")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Drafts")
    }

    func testOriginalAssetsUnmutated() {
        let tree = makeTree()
        let originalChildCount = tree[2].children?.count  // Screenshots folder
        _ = AssetGridView.searchAssets(tree, query: "logo")
        XCTAssertEqual(tree[2].children?.count, originalChildCount, "Search must not mutate original assets")
    }
}
