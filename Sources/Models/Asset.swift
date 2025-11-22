import Foundation
import SwiftData

@Model
final class Asset {
    var id: UUID
    var creationDate: Date
    var type: AssetType
    var textContent: String?
    @Attribute(.externalStorage) var imageData: Data?
    
    init(type: AssetType, textContent: String? = nil, imageData: Data? = nil) {
        self.id = UUID()
        self.creationDate = Date()
        self.type = type
        self.textContent = textContent
        self.imageData = imageData
    }
}

enum AssetType: String, Codable {
    case text
    case image
}
