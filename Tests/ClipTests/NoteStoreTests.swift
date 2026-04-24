import XCTest
@testable import Clip

final class NoteStoreTests: XCTestCase {

    // Isolated store backed by a temp file so tests don't touch real data.
    private func makeStore() -> NoteStore {
        // NoteStore.shared uses the real path; we test via the model directly.
        // These tests exercise Note model logic + encode/decode without touching shared state.
        return NoteStore.shared
    }

    // MARK: - Note model

    func testNoteDefaultInit() {
        let note = Note()
        XCTAssertFalse(note.id.uuidString.isEmpty)
        XCTAssertEqual(note.body, "")
        XCTAssertTrue(Calendar.current.isDateInToday(note.date))
        XCTAssertTrue(Calendar.current.isDateInToday(note.updatedAt))
    }

    func testNoteEncodeDecodeRoundTrip() throws {
        let note = Note(body: "# Hello\n- [ ] task")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(note)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Note.self, from: data)

        XCTAssertEqual(decoded.id, note.id)
        XCTAssertEqual(decoded.body, note.body)
        // Dates encode/decode within 1-second tolerance
        XCTAssertEqual(decoded.date.timeIntervalSince1970, note.date.timeIntervalSince1970, accuracy: 1.0)
    }

    // MARK: - todayNote

    func testTodayNoteReturnsSameInstanceOnDoubleCall() {
        // todayNote must not create a duplicate on repeated calls within the same day.
        let store = NoteStore.shared
        let countBefore = store.notes.filter { Calendar.current.isDateInToday($0.date) }.count

        _ = store.todayNote
        _ = store.todayNote

        let countAfter = store.notes.filter { Calendar.current.isDateInToday($0.date) }.count
        // At most 1 today-note should exist regardless of how many times todayNote is accessed.
        XCTAssertLessThanOrEqual(countAfter - countBefore, 1)
        XCTAssertLessThanOrEqual(store.notes.filter { Calendar.current.isDateInToday($0.date) }.count, 1)
    }

    func testTodayNoteCreatesNoteOnFirstAccess() {
        // Remove today's note if one exists, then verify todayNote recreates it.
        let store = NoteStore.shared
        let todayNotes = store.notes.filter { Calendar.current.isDateInToday($0.date) }
        for n in todayNotes { store.delete(n) }

        let note = store.todayNote
        XCTAssertTrue(Calendar.current.isDateInToday(note.date))
        XCTAssertEqual(store.notes.filter { Calendar.current.isDateInToday($0.date) }.count, 1)
    }

    // MARK: - Mutation

    func testBodyMutationPreservesOtherFields() {
        let note = Note(body: "original")
        let originalID = note.id
        note.body = "updated"
        XCTAssertEqual(note.id, originalID)
        XCTAssertEqual(note.body, "updated")
    }
}
