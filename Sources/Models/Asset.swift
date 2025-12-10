import Foundation
import Observation

@Observable
final class Asset: Identifiable, Codable {
    var id: UUID
    var creationDate: Date
    var type: AssetType
    var textContent: String?
    var imageData: Data?
    var name: String? // Optional name, especially for folders
    var children: [Asset]? // For recursive folder structure
    
    init(type: AssetType, textContent: String? = nil, imageData: Data? = nil, name: String? = nil, children: [Asset]? = nil) {
        self.id = UUID()
        self.creationDate = Date()
        self.type = type
        self.textContent = textContent
        self.imageData = imageData
        self.name = name
        self.children = children
    }
    
    
    // Explicit Codable conformance to avoid @Observable macro issues
    enum CodingKeys: String, CodingKey {
        case id, creationDate, type, textContent, imageData, name, children
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.creationDate = try container.decode(Date.self, forKey: .creationDate)
        self.type = try container.decode(AssetType.self, forKey: .type)
        self.textContent = try container.decodeIfPresent(String.self, forKey: .textContent)
        self.imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.children = try container.decodeIfPresent([Asset].self, forKey: .children)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(creationDate, forKey: .creationDate)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(textContent, forKey: .textContent)
        try container.encodeIfPresent(imageData, forKey: .imageData)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(children, forKey: .children)
    }
}

enum AssetType: String, Codable {
    case text
    case image
    case folder
}
