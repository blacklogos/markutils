import XCTest
@testable import Clip

final class FolderTests: XCTestCase {
    
    func testAssetFolderCreation() throws {
        // Create child assets
        let child1 = Asset(type: .text, textContent: "Hello", name: "child1.txt")
        let child2 = Asset(type: .image, imageData: Data(), name: "child2.png")
        
        // Create folder asset
        let folder = Asset(type: .folder, name: "TestFolder", children: [child1, child2])
        
        // Verify
        XCTAssertEqual(folder.type, .folder)
        XCTAssertEqual(folder.name, "TestFolder")
        XCTAssertEqual(folder.children?.count, 2)
        XCTAssertEqual(folder.children?[0].name, "child1.txt")
    }
    
    func testAssetEncoding() throws {
        let child = Asset(type: .text, textContent: "Child", name: "child.txt")
        let folder = Asset(type: .folder, name: "Parent", children: [child])
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(folder)
        
        let decoder = JSONDecoder()
        let decodedFolder = try decoder.decode(Asset.self, from: data)
        
        XCTAssertEqual(decodedFolder.name, "Parent")
        XCTAssertEqual(decodedFolder.children?.count, 1)
        XCTAssertEqual(decodedFolder.children?.first?.name, "child.txt")
    }
}
