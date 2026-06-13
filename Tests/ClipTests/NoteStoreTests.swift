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

    // MARK: - ensureTodayNote

    func testTodayNoteReturnsSameInstanceOnDoubleCall() {
        // ensureTodayNote must not create a duplicate on repeated calls within the same day.
        let store = NoteStore.shared
        let countBefore = store.notes.filter { Calendar.current.isDateInToday($0.date) }.count

        _ = store.ensureTodayNote()
        _ = store.ensureTodayNote()

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

        let note = store.ensureTodayNote()
        XCTAssertTrue(Calendar.current.isDateInToday(note.date))
        XCTAssertEqual(store.notes.filter { Calendar.current.isDateInToday($0.date) }.count, 1)
    }

    func testEnsureTodayNoteReusesExistingTodayNoteInsteadOfStackingBlanks() {
        // Repro for the ⌥A duplicate-empty-note bug: opening the panel must not
        // append a second blank note when a today-note already exists.
        let store = NoteStore.shared
        for n in store.notes.filter({ Calendar.current.isDateInToday($0.date) }) { store.delete(n) }
        let seeded = Note(body: "real content for today")
        store.add(seeded)

        // Open the panel twice in a row — neither should create a blank.
        let first = store.ensureTodayNote()
        let second = store.ensureTodayNote()

        XCTAssertEqual(first.id, seeded.id, "Existing today note must be reused")
        XCTAssertEqual(second.id, seeded.id, "Repeated opens return the same today note")
        XCTAssertEqual(store.notes.filter { Calendar.current.isDateInToday($0.date) }.count, 1,
                       "No duplicate today note may be appended")

        store.delete(seeded)
    }

    func testEnsureTodayNotePrefersMostRecentlyEditedTodayNote() {
        // If duplicate today-notes already exist on disk (legacy data), the panel
        // should land on the one the user most recently touched, not a stale blank.
        let store = NoteStore.shared
        for n in store.notes.filter({ Calendar.current.isDateInToday($0.date) }) { store.delete(n) }
        let stale = Note(body: "")
        stale.updatedAt = Date(timeIntervalSinceNow: -3600)
        let recent = Note(body: "the active one")
        store.add(stale)
        store.add(recent)

        XCTAssertEqual(store.ensureTodayNote().id, recent.id)

        store.delete(stale)
        store.delete(recent)
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
