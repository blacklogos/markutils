import Foundation

// Vietnamese-aware styling support for UnicodeTextFormatter.
//
// The Unicode mathematical alphabets cover only ASCII A-Z/a-z/0-9; Vietnamese
// letters (base + tone marks, plus đ/Đ) have no styled codepoints. Two strategies:
//   .accent  — decompose the letter (NFD), style the ASCII base, reattach the
//              combining marks. Fully styled, but mark rendering is font-dependent.
//   .natural — leave words containing Vietnamese marks untouched and style only
//              ASCII tokens (AI, 247, #hashtags). Renders safely everywhere.
extension UnicodeTextFormatter {

    /// How to style text that contains Vietnamese (or other combining-mark) letters.
    public enum VietnameseMode {
        case accent
        case natural
    }

    // MARK: - Accent strategy

    /// Styles every character; accented letters are decomposed so their ASCII base
    /// gets the styled glyph and the combining marks are re-attached on top.
    static func applyAccent(map: [Character: Character], to text: String) -> String {
        text.map { char in
            if let direct = map[char] { return String(direct) }
            return accentStyled(char, map: map) ?? String(char)
        }.joined()
    }

    // đ/Đ have no combining-mark decomposition; approximate with a combining
    // short stroke overlay (U+0335) on the styled d/D.
    private static let strokedD: [Character: (base: Character, marks: String)] = [
        "đ": ("d", "\u{0335}"),
        "Đ": ("D", "\u{0335}"),
    ]

    /// Styles one accented character: mapped base letter + original combining marks.
    /// Returns nil when the character has no mappable ASCII base.
    private static func accentStyled(_ char: Character, map: [Character: Character]) -> String? {
        if let d = strokedD[char], let mapped = map[d.base] {
            return String(mapped) + d.marks
        }
        let scalars = Array(String(char).decomposedStringWithCanonicalMapping.unicodeScalars)
        guard scalars.count > 1,
              let mappedBase = map[Character(scalars[0])],
              scalars.dropFirst().allSatisfy(isCombiningMark)
        else { return nil }
        return String(mappedBase) + String(String.UnicodeScalarView(scalars.dropFirst()))
    }

    // MARK: - Natural strategy

    /// Styles ASCII tokens only; words carrying Vietnamese marks stay plain.
    /// Falls back to the accent strategy when the whole input is Vietnamese,
    /// so the transform is never a no-op.
    static func applyNatural(map: [Character: Character], to text: String) -> String {
        var output = ""
        for token in tokenizeWords(text) {
            if token.isWord && hasVietnameseMarks(token.value) {
                output += token.value
            } else {
                output += token.value.map { map[$0].map(String.init) ?? String($0) }.joined()
            }
        }
        if output == text && hasVietnameseMarks(text) {
            return applyAccent(map: map, to: text)
        }
        return output
    }

    /// True if text contains đ/Đ or any combining diacritical mark after NFD.
    static func hasVietnameseMarks(_ text: String) -> Bool {
        if text.contains("đ") || text.contains("Đ") { return true }
        return text.decomposedStringWithCanonicalMapping.unicodeScalars.contains(where: isCombiningMark)
    }

    static func isCombiningMark(_ scalar: Unicode.Scalar) -> Bool {
        (0x0300...0x036F).contains(scalar.value)
    }

    private struct Token {
        let isWord: Bool
        var value: String
    }

    /// Splits text into word runs (letters/digits/_/#/@) and non-word runs.
    private static func tokenizeWords(_ text: String) -> [Token] {
        var tokens: [Token] = []
        for char in text {
            let isWord = char.isLetter || char.isNumber || char == "_" || char == "#" || char == "@"
            if !tokens.isEmpty, tokens[tokens.count - 1].isWord == isWord {
                tokens[tokens.count - 1].value.append(char)
            } else {
                tokens.append(Token(isWord: isWord, value: String(char)))
            }
        }
        return tokens
    }

    // MARK: - Combining-mark decoration (underline / strikethrough)

    /// Appends a combining mark after each letter/digit Character. Operating on
    /// Characters (graphemes) keeps the mark after a full "base + tone marks"
    /// cluster, and skipping spaces/punctuation avoids floating decorations.
    static func addCombiningMark(_ mark: String, to text: String) -> String {
        text.map { char in
            (char.isLetter || char.isNumber) ? String(char) + mark : String(char)
        }.joined()
    }
}
