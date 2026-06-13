import XCTest
@testable import Clip
import ClipCore

final class TableTransformerTests: XCTestCase {

    // MARK: - TSV <-> CSV (moved out of QuickActionsView)

    func testTSVToCSVQuotesFieldsWithCommas() {
        let tsv = "name\tnote\nAcme\thello, world"
        let csv = TableTransformer.tsvToCSV(tsv)
        XCTAssertEqual(csv, "name,note\nAcme,\"hello, world\"")
    }

    func testTSVToCSVEscapesQuotes() {
        let tsv = "a\tsay \"hi\""
        let csv = TableTransformer.tsvToCSV(tsv)
        XCTAssertEqual(csv, "a,\"say \"\"hi\"\"\"")
    }

    func testCSVToTSVHandlesQuotedCommas() {
        let csv = "name,note\nAcme,\"hello, world\""
        let tsv = TableTransformer.csvToTSV(csv)
        XCTAssertEqual(tsv, "name\tnote\nAcme\thello, world")
    }

    func testTSVCSVRoundTrip() {
        let tsv = "h1\th2\nval, with comma\tplain"
        let back = TableTransformer.csvToTSV(TableTransformer.tsvToCSV(tsv))
        XCTAssertEqual(back, tsv)
    }
}
