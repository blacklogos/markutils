import Foundation
import Observation

// MARK: - Snippet Model

@Observable
final class Snippet: Identifiable, Codable {
    var id: UUID
    var name: String
    var content: String
    var category: String?
    var isBuiltIn: Bool
    var creationDate: Date

    init(name: String, content: String, category: String? = nil, isBuiltIn: Bool = false) {
        self.id = UUID()
        self.name = name
        self.content = content
        self.category = category
        self.isBuiltIn = isBuiltIn
        self.creationDate = Date()
    }

    enum CodingKeys: String, CodingKey {
        case id, name, content, category, isBuiltIn, creationDate
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        content = try c.decode(String.self, forKey: .content)
        category = try c.decodeIfPresent(String.self, forKey: .category)
        isBuiltIn = try c.decode(Bool.self, forKey: .isBuiltIn)
        creationDate = try c.decode(Date.self, forKey: .creationDate)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(content, forKey: .content)
        try c.encodeIfPresent(category, forKey: .category)
        try c.encode(isBuiltIn, forKey: .isBuiltIn)
        try c.encode(creationDate, forKey: .creationDate)
    }
}

// MARK: - Snippet Store

@Observable
class SnippetStore {
    static let shared = SnippetStore()

    var snippets: [Snippet] = [] {
        didSet { save() }
    }

    private let fileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Clip")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.fileURL = appDir.appendingPathComponent("snippets.json")
        load()
        if snippets.filter({ $0.isBuiltIn }).isEmpty {
            seedBuiltIns()
        }
    }

    func add(_ snippet: Snippet) {
        snippets.append(snippet)
    }

    func delete(_ snippet: Snippet) {
        guard !snippet.isBuiltIn else { return }
        snippets.removeAll { $0.id == snippet.id }
    }

    func duplicate(_ snippet: Snippet) {
        let copy = Snippet(
            name: "\(snippet.name) Copy",
            content: snippet.content,
            category: snippet.category,
            isBuiltIn: false
        )
        snippets.append(copy)
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(snippets)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save snippets: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            snippets = try JSONDecoder().decode([Snippet].self, from: data)
        } catch {
            print("Failed to load snippets: \(error)")
        }
    }

    // MARK: - Built-in Templates

    private func seedBuiltIns() {
        let builtIns: [Snippet] = [
            Snippet(name: "Meeting Notes", content: """
                # Meeting Notes — [Date]

                **Attendees:**

                ## Agenda
                -

                ## Discussion

                ## Action Items
                - [ ]
                """, category: "Templates", isBuiltIn: true),

            Snippet(name: "Slide Outline", content: """
                # [Presentation Title]

                ## Section 1
                - Key point
                - Supporting detail

                ## Section 2
                - Key point
                - Supporting detail

                ## Summary
                - Takeaway 1
                - Takeaway 2
                """, category: "Templates", isBuiltIn: true),

            Snippet(name: "Proposal Structure", content: """
                # Proposal: [Title]

                ## Executive Summary

                ## Problem

                ## Solution

                ## Timeline
                | Phase | Description | Duration |
                |-------|-------------|----------|
                | 1     |             |          |

                ## Pricing

                ## Next Steps
                """, category: "Templates", isBuiltIn: true),

            Snippet(name: "Comparison Table", content: """
                | Feature | Option A | Option B |
                |---------|----------|----------|
                |         |          |          |
                |         |          |          |
                """, category: "Templates", isBuiltIn: true),
        ]
        snippets.append(contentsOf: builtIns)
    }
}
