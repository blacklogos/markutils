import XCTest
@testable import Clip

final class ClipTests: XCTestCase {

    // MARK: - Asset Tests

    func testAssetCreation() {
        // Test Image Asset
        let imageData = Data([0x00, 0x01, 0x02])
        let imageAsset = Asset(type: .image, imageData: imageData)
        
        XCTAssertEqual(imageAsset.type, .image)
        XCTAssertEqual(imageAsset.imageData, imageData)
        XCTAssertNil(imageAsset.textContent)
        
        // Test Text Asset
        let textContent = "Hello World"
        let textAsset = Asset(type: .text, textContent: textContent)
        
        XCTAssertEqual(textAsset.type, .text)
        XCTAssertEqual(textAsset.textContent, textContent)
        XCTAssertNil(textAsset.imageData)
    }
}
