import XCTest
@testable import Clip

final class ImageFormatTests: XCTestCase {

    // MARK: - SVG Detection

    func testSVGDetectionWithSvgTag() {
        XCTAssertTrue(isSVG("<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 100 100\"></svg>"))
    }

    func testSVGDetectionWithXmlDeclaration() {
        XCTAssertTrue(isSVG("<?xml version=\"1.0\"?><svg></svg>"))
    }

    func testSVGDetectionWithLeadingWhitespace() {
        XCTAssertTrue(isSVG("  \n  <svg></svg>"))
    }

    func testSVGDetectionNegativeForHTML() {
        XCTAssertFalse(isSVG("<html><body>Hello</body></html>"))
    }

    func testSVGDetectionNegativeForPlainText() {
        XCTAssertFalse(isSVG("Hello world"))
    }

    func testSVGDetectionNegativeForEmpty() {
        XCTAssertFalse(isSVG(""))
    }

    func testSVGDetectionNegativeForMarkdown() {
        XCTAssertFalse(isSVG("# Hello\n**bold**"))
    }

    // MARK: - PNG Conversion (basic)

    func testPNGFromImageData() throws {
        // Create a 1x1 red PNG programmatically
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(x: 0, y: 0, width: 1, height: 1))
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to create PNG from NSImage")
            return
        }

        XCTAssertTrue(png.count > 0)
        // Verify PNG magic bytes
        let magic = [UInt8](png.prefix(4))
        XCTAssertEqual(magic, [0x89, 0x50, 0x4E, 0x47]) // PNG signature
    }

    // MARK: - Helper (mirrors AssetItemView logic)

    private func isSVG(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("<svg") || trimmed.hasPrefix("<?xml")
    }
}
