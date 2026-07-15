import XCTest
@testable import Clip
import ClipCore

final class UnicodeTextFormatterVietnameseTests: XCTestCase {

    // MARK: - Accent mode (default)

    func testAccentModeStylesAccentedLetters() {
        // "mắt" → every letter styled; ắ = styled a + breve + acute
        let out = UnicodeTextFormatter.apply(.bold, to: "mắt")
        XCTAssertEqual(out, "𝐦𝐚\u{0306}\u{0301}𝐭")
    }

    func testAccentModeWholeVietnamesePhrase() {
        let out = UnicodeTextFormatter.apply(.bold, to: "Chào")
        // No plain ASCII letters may survive (the old mid-word flicker)
        XCTAssertFalse(out.contains("C"))
        XCTAssertFalse(out.contains("h"))
        XCTAssertFalse(out.contains("o"))
        XCTAssertTrue(out.contains("\u{0300}"))  // grave tone mark retained
    }

    func testAccentModeStrokedD() {
        XCTAssertEqual(UnicodeTextFormatter.apply(.bold, to: "đ"), "𝐝\u{0335}")
        XCTAssertEqual(UnicodeTextFormatter.apply(.bold, to: "Đ"), "𝐃\u{0335}")
    }

    func testAccentModeHandlesNFDInput() {
        // "ắ" supplied pre-decomposed (a + breve + acute)
        let nfd = "a\u{0306}\u{0301}"
        XCTAssertEqual(UnicodeTextFormatter.apply(.bold, to: nfd), "𝐚\u{0306}\u{0301}")
    }

    func testAccentModeLeavesUnmappableCharsAlone() {
        XCTAssertEqual(UnicodeTextFormatter.apply(.bold, to: "日本 ok"), "日本 𝐨𝐤")
    }

    // MARK: - Natural mode

    func testNaturalModeSkipsVietnameseWordsStylesASCII() {
        let out = UnicodeTextFormatter.apply(.bold, to: "Ra mắt AI 247 #startup", mode: .natural)
        XCTAssertEqual(out, "𝐑𝐚 mắt 𝐀𝐈 𝟐𝟒𝟕 #𝐬𝐭𝐚𝐫𝐭𝐮𝐩")
    }

    func testNaturalModeFallsBackToAccentWhenAllVietnamese() {
        // Whole input Vietnamese → would be a no-op → falls back to accent styling
        let out = UnicodeTextFormatter.apply(.bold, to: "mắt", mode: .natural)
        XCTAssertEqual(out, "𝐦𝐚\u{0306}\u{0301}𝐭")
    }

    func testNaturalModeSkipsWordsWithStrokedD() {
        let out = UnicodeTextFormatter.apply(.bold, to: "Đặng ok", mode: .natural)
        XCTAssertEqual(out, "Đặng 𝐨𝐤")
    }

    // MARK: - Underline / strikethrough decoration

    func testUnderlineSkipsSpacesAndPunctuation() {
        let out = UnicodeTextFormatter.apply(.underline, to: "ab c!")
        XCTAssertEqual(out, "a\u{0332}b\u{0332} c\u{0332}!")
    }

    func testUnderlineKeepsToneMarkClusterIntact() {
        // Mark goes after the full grapheme (base + tone marks), not between them
        let out = UnicodeTextFormatter.apply(.underline, to: "mắt")
        XCTAssertEqual(out, "m\u{0332}ắ\u{0332}t\u{0332}")
    }

    func testStrikethroughSkipsSpaces() {
        let out = UnicodeTextFormatter.apply(.strikethrough, to: "a b")
        XCTAssertEqual(out, "a\u{0336} b\u{0336}")
    }

    // MARK: - Revert round-trips

    func testRevertAccentStyledVietnamese() {
        let styled = UnicodeTextFormatter.apply(.bold, to: "Chào mừng Tiếng Việt")
        XCTAssertEqual(UnicodeTextFormatter.revertToPlain(styled), "Chào mừng Tiếng Việt")
    }

    func testRevertStrokedD() {
        let styled = UnicodeTextFormatter.apply(.bold, to: "Đặng đi đâu")
        XCTAssertEqual(UnicodeTextFormatter.revertToPlain(styled), "Đặng đi đâu")
    }

    func testRevertUnderlinedVietnamese() {
        let styled = UnicodeTextFormatter.apply(.underline, to: "mắt")
        XCTAssertEqual(UnicodeTextFormatter.revertToPlain(styled), "mắt")
    }

    func testRevertPlainASCIIStyles() {
        for style: UnicodeTextFormatter.Style in [.bold, .italic, .boldItalic, .monospace, .smallCaps] {
            let styled = UnicodeTextFormatter.apply(style, to: "Hello World 42")
            let reverted = UnicodeTextFormatter.revertToPlain(styled)
            // q, x have no small caps mapping; they pass through unchanged either way
            XCTAssertEqual(reverted, "Hello World 42", "revert failed for \(style)")
        }
    }

    // MARK: - markdownToUnicode mode threading

    func testMarkdownToUnicodeNaturalMode() {
        let out = UnicodeTextFormatter.markdownToUnicode("**Ra mắt AI**", mode: .natural)
        XCTAssertEqual(out, "𝐑𝐚 mắt 𝐀𝐈")
    }

    func testMarkdownToUnicodeDefaultAccentMode() {
        let out = UnicodeTextFormatter.markdownToUnicode("**mắt**")
        XCTAssertEqual(out, "𝐦𝐚\u{0306}\u{0301}𝐭")
    }
}
