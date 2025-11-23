import XCTest
@testable import Clip

final class ClipTests: XCTestCase {
    
    // MARK: - AIService Tests
    
    func testAIServiceSummarize() async throws {
        let service = AIService.shared
        let input = "Line 1\nLine 2\nLine 3"
        let result = try await service.summarize(input)
        
        XCTAssertTrue(result.contains("**Summary:**"))
        XCTAssertTrue(result.contains("(AI Generated)"))
    }
    
    func testAIServiceSlideGeneration() async throws {
        let service = AIService.shared
        let input = "My Startup Idea"
        
        // Test Consulting Template
        let consulting = try await service.generateSlideDeck(from: input, template: .consulting)
        XCTAssertTrue(consulting.contains("# Slide 1: Executive Summary"))
        XCTAssertTrue(consulting.contains("(Generated with Consulting Template ✨)"))
        
        // Test Sales Template
        let sales = try await service.generateSlideDeck(from: input, template: .sales)
        XCTAssertTrue(sales.contains("# Slide 1: The Problem"))
        XCTAssertTrue(sales.contains("(Generated with Sales Template ✨)"))
    }
    
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
