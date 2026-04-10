import XCTest
@testable import Clip

final class AssetFormatTests: XCTestCase {

    // MARK: - Backward Compatibility

    func testDecodeOldJSONWithoutFileFormat() throws {
        // Simulate JSON from v1.3.0 (no fileFormat field)
        let json = """
        {
            "id": "550E8400-E29B-41D4-A716-446655440000",
            "creationDate": 704067200,
            "type": "text",
            "textContent": "Hello",
            "name": "greeting.txt"
        }
        """.data(using: .utf8)!

        let asset = try JSONDecoder().decode(Asset.self, from: json)
        XCTAssertEqual(asset.name, "greeting.txt")
        XCTAssertEqual(asset.textContent, "Hello")
        XCTAssertNil(asset.fileFormat, "Old assets should decode with nil fileFormat")
    }

    // MARK: - Encode/Decode Round-Trip

    func testFileFormatRoundTrip() throws {
        let asset = Asset(type: .text, textContent: "# README", name: "readme.md", fileFormat: "md")

        let data = try JSONEncoder().encode(asset)
        let decoded = try JSONDecoder().decode(Asset.self, from: data)

        XCTAssertEqual(decoded.fileFormat, "md")
        XCTAssertEqual(decoded.name, "readme.md")
        XCTAssertEqual(decoded.textContent, "# README")
    }

    func testFileFormatNilRoundTrip() throws {
        let asset = Asset(type: .text, textContent: "plain text", name: "note.txt")
        XCTAssertNil(asset.fileFormat)

        let data = try JSONEncoder().encode(asset)
        let decoded = try JSONDecoder().decode(Asset.self, from: data)

        XCTAssertNil(decoded.fileFormat)
    }

    // MARK: - VaultAsset Interop (CLI ↔ App)

    func testVaultAssetDecodesFileFormat() throws {
        // Encode as app Asset, decode as CLI VaultAsset
        let asset = Asset(type: .text, textContent: "# Doc", name: "doc.md", fileFormat: "md")
        let data = try JSONEncoder().encode(asset)

        // VaultAsset is in the CLI target — we can't import it here.
        // Instead, verify the JSON contains the fileFormat key.
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["fileFormat"] as? String, "md")
    }

    // MARK: - Markdown Detection Helper

    func testMarkdownAssetDetection() {
        let mdAsset = Asset(type: .text, textContent: "# Hello", name: "readme.md", fileFormat: "md")
        let txtAsset = Asset(type: .text, textContent: "Hello", name: "note.txt", fileFormat: "txt")
        let noFormatAsset = Asset(type: .text, textContent: "Hello", name: "note.txt")
        let imgAsset = Asset(type: .image, imageData: Data(), name: "pic.png")

        XCTAssertTrue(isMarkdown(mdAsset))
        XCTAssertFalse(isMarkdown(txtAsset))
        XCTAssertFalse(isMarkdown(noFormatAsset))
        XCTAssertFalse(isMarkdown(imgAsset))
    }

    // Mirror the detection logic from AssetItemView
    private func isMarkdown(_ asset: Asset) -> Bool {
        guard asset.type == .text else { return false }
        let fmt = asset.fileFormat ?? ""
        return fmt == "md" || fmt == "markdown"
    }
}
