import Foundation
import Observation

// MARK: - Note Model

@Observable
final class Note: Identifiable, Codable {
    var id: UUID
    var body: String
    var date: Date       // creation day (full timestamp; compare by day via Calendar)
    var updatedAt: Date

    init(body: String = "") {
        self.id = UUID()
        self.body = body
        self.date = Date()
        self.updatedAt = Date()
    }

    enum CodingKeys: String, CodingKey {
        case id, body, date, updatedAt
    }

    required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(UUID.self,   forKey: .id)
        body      = try c.decode(String.self, forKey: .body)
        date      = try c.decode(Date.self,   forKey: .date)
        updatedAt = try c.decode(Date.self,   forKey: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,        forKey: .id)
        try c.encode(body,      forKey: .body)
        try c.encode(date,      forKey: .date)
        try c.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - NoteStore

@Observable
final class NoteStore {
    static let shared = NoteStore()

    var notes: [Note] = [] {
        didSet { save() }
    }

    private let fileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Clip")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.fileURL = appDir.appendingPathComponent("notes.json")
        load()
    }

    // Returns today's note, creating one if none exists for today.
    var todayNote: Note {
        if let existing = notes.first(where: { Calendar.current.isDateInToday($0.date) }) {
            return existing
        }
        let note = Note()
        add(note)
        return note
    }

    func add(_ note: Note) {
        notes.append(note)
    }

    func delete(_ note: Note) {
        notes.removeAll { $0.id == note.id }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(notes)
            try data.write(to: fileURL)
        } catch {
            print("NoteStore save failed: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            notes = try JSONDecoder().decode([Note].self, from: data)
        } catch {
            print("NoteStore load failed: \(error)")
        }
    }
}
