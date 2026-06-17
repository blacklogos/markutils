import XCTest
@testable import Clip
import ClipCore

// JS/DOM selection + highlight wrapping is verified manually (no UI-XCTest under
// CommandLineTools — project constraint). These tests cover the native-side
// shape validation and the JS-argument escaping boundary.
final class AnnotatablePreviewCoordinatorTests: XCTestCase {

    typealias Coordinator = AnnotatableHTMLPreviewView.Coordinator

    // MARK: - selection message validation

    func testSelectionMessageMissingQuoteIsDropped() {
        XCTAssertNil(Coordinator.parseSelection(["prefix": "a", "suffix": "b"]))
    }

    func testSelectionMessageEmptyQuoteIsDropped() {
        XCTAssertNil(Coordinator.parseSelection(["quote": "   ", "prefix": "a", "suffix": "b"]))
    }

    func testSelectionMessageWrongTypeIsDropped() {
        XCTAssertNil(Coordinator.parseSelection("not a dict"))
        XCTAssertNil(Coordinator.parseSelection(["quote": 42]))
    }

    func testWellFormedSelectionParses() {
        let parsed = Coordinator.parseSelection(["quote": "hello", "prefix": "pre ", "suffix": " post"])
        XCTAssertEqual(parsed?.quote, "hello")
        XCTAssertEqual(parsed?.prefix, "pre ")
        XCTAssertEqual(parsed?.suffix, " post")
    }

    func testSelectionDefaultsMissingContextToEmpty() {
        let parsed = Coordinator.parseSelection(["quote": "hello"])
        XCTAssertEqual(parsed?.prefix, "")
        XCTAssertEqual(parsed?.suffix, "")
    }

    // MARK: - commentClicked validation

    func testCommentClickedNonStringIdIsDropped() {
        XCTAssertNil(Coordinator.parseCommentClicked(["id": 123]))
    }

    func testCommentClickedNonUUIDStringIsDropped() {
        XCTAssertNil(Coordinator.parseCommentClicked(["id": "not-a-uuid"]))
    }

    func testCommentClickedValidUUIDParses() {
        let id = UUID()
        XCTAssertEqual(Coordinator.parseCommentClicked(["id": id.uuidString]), id)
    }

    // MARK: - JS-argument escaping

    func testAnchorsJSONEscapesSpecialCharactersAndRoundTrips() throws {
        let nasty = #"</mark><script>alert("x")</script> & <b>"#
        let comment = Comment(quote: nasty, prefix: "p\"<", suffix: "&>", note: "n")
        let json = AnnotatableHTMLPreviewView.anchorsJSON(for: [comment])

        // The raw, unescaped script tag must not appear verbatim in the JS argument.
        XCTAssertFalse(json.contains("<script>alert(\"x\")"),
                       "User text must be JSON-escaped before reaching the DOM")

        // It must decode back to exactly the original strings (lossless escaping).
        let decoded = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: String]]
        XCTAssertEqual(decoded?.first?["quote"], nasty)
        XCTAssertEqual(decoded?.first?["id"], comment.id.uuidString)
    }

    func testAnchorsJSONEmptyForNoComments() {
        XCTAssertEqual(AnnotatableHTMLPreviewView.anchorsJSON(for: []), "[]")
    }
}
