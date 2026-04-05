# Unicode Text Formatter Enhancement Plan

## Goal
Enhance Text Formatter tab to convert markdown/rich text → Unicode-styled plain text for social media (LinkedIn, Twitter, Facebook) where markdown isn't supported but Unicode renders.

## Approach
Add "Convert" sub-mode to existing Text Formatter tab via segmented picker: `Format | Convert`

---

## New File: `Sources/Utilities/UnicodeTextFormatter.swift`

Extract existing `toBold`/`toItalic`/`mapChars` from `SocialMediaFormatterView.swift` + add new styles.

### Unicode Style Maps

| Style | Example | Unicode Range |
|-------|---------|--------------|
| Bold | 𝐁𝐨𝐥𝐝 | Mathematical Bold (existing) |
| Italic | 𝘐𝘵𝘢𝘭𝘪𝘤 | Mathematical Italic (existing) |
| Bold Italic | 𝙗𝙤𝙡𝙙 | Mathematical Bold Italic (new) |
| Monospace | 𝚖𝚘𝚗𝚘 | Mathematical Monospace (new) |
| Script | 𝒮𝒸𝓇𝒾𝓅𝓉 | Mathematical Script (new) |
| Small Caps | ꜱᴍᴀʟʟ | Latin Small Caps (new) |
| Underline | u̲n̲d̲e̲r̲ | Combining U+0332 (new) |
| Strikethrough | s̶t̶r̶i̶k̶e̶ | Combining U+0336 (new) |

### Core API

```swift
struct UnicodeTextFormatter {
    enum Style { case bold, italic, boldItalic, monospace, script, smallCaps, underline, strikethrough }

    // Single style application
    static func apply(_ style: Style, to text: String) -> String

    // Markdown → Unicode auto-conversion
    // **bold** → 𝐛𝐨𝐥𝐝, *italic* → 𝘪𝘵𝘢𝘭𝘪𝘤, `code` → 𝚌𝚘𝚍𝚎
    // # Header → 𝐇𝐄𝐀𝐃𝐄𝐑 (bold + uppercase)
    // - item → • item
    // 1. item → 1️⃣ item (or keep as-is)
    // --- → ─────────────────
    static func markdownToUnicode(_ markdown: String) -> String

    // Markdown table → ASCII box-drawn table
    // | A | B |     ┌───┬───┐
    // |---|---|  →   │ A │ B │
    // | 1 | 2 |     ├───┼───┤
    //                │ 1 │ 2 │
    //                └───┴───┘
    static func markdownTableToASCII(_ markdown: String) -> String
}
```

### Markdown → Unicode Conversion Rules

```
**text**        → apply(.bold, "text")
*text*          → apply(.italic, "text")
***text***      → apply(.boldItalic, "text")
`code`          → apply(.monospace, "code")
~~text~~        → apply(.strikethrough, "text")
# Header        → apply(.bold, header.uppercased()) + newline
## Subheader    → apply(.bold, subheader)
### H3          → apply(.italic, h3)
- item          → "• item"
* item          → "• item"
1. item         → "1. item" (keep as-is, already looks good)
> quote         → "│ quote" (box-drawing vertical bar)
---             → "─────────────────" (box-drawing horizontal)
[text](url)     → "text (url)" or just "text" (configurable)
```

### ASCII Box-Drawing Table

Uses box-drawing characters:
- Corners: `┌ ┐ └ ┘`
- Edges: `─ │`
- Junctions: `┬ ┴ ├ ┤ ┼`
- Header separator: `╞ ═ ╡ ╪` (double line under header)

Logic:
1. Parse markdown table rows (reuse `RichTextTransformer.parseTableRow`)
2. Calculate max column widths
3. Render with box characters, pad cells to width

### Vietnamese Note
Non-mapped chars (including Vietnamese diacritics) pass through unchanged via existing `mapChars` logic. Diacritics render correctly in their original form — they just won't have the mathematical styling. This is acceptable and consistent with how all Unicode formatters work.

---

## Modified File: `Sources/Views/SocialMediaFormatterView.swift`

### Changes
1. Add segmented picker at top: `Format | Convert`
2. **Format mode**: existing toolbar (bold, italic, bullets, emojis, footer, copy) — unchanged
3. **Convert mode**: new UI below editor:
   - "Markdown → Unicode" button — runs `markdownToUnicode` on full editor text
   - "Table → ASCII" button — runs `markdownTableToASCII` on selected text or full text
   - Style override buttons: apply a single style to selection (Bold, Italic, Mono, Script, SmallCaps, Underline, Strike)
   - "Revert to Plain" button — strips Unicode styling back to ASCII
4. Remove `toBold`/`toItalic`/`mapChars` methods — replaced by `UnicodeTextFormatter`
5. Update existing Bold/Italic toolbar buttons in Format mode to call `UnicodeTextFormatter.apply()` instead

### Convert Mode Layout

```
┌─────────────────────────────────────────┐
│ [Format] [Convert]                      │  ← segmented picker
├─────────────────────────────────────────┤
│ Auto-Convert:                           │
│ [MD → Unicode]  [Table → ASCII]         │  ← full-text converters
│                                         │
│ Style Selection:                        │
│ [𝐁] [𝘐] [𝙗𝙞] [𝚖] [𝒮] [ꜱᴄ] [u̲] [s̶]   │  ← apply to selection
│                                         │
│ [Revert to Plain]              [Copy]   │
├─────────────────────────────────────────┤
│                                         │
│  (editor — same MacEditorView)          │
│                                         │
└─────────────────────────────────────────┘
```

---

## File Changes Summary

| File | Action |
|------|--------|
| `Sources/Utilities/UnicodeTextFormatter.swift` | NEW — all Unicode mapping + conversion logic |
| `Sources/Views/SocialMediaFormatterView.swift` | MODIFY — add Convert mode, delegate to UnicodeTextFormatter |

## Dependencies
- None. Pure Swift string manipulation. No external packages.
- Reuse `RichTextTransformer.parseTableRow` for ASCII table parsing (already exists).

## Risks
- **ASCII tables in proportional fonts**: Box-drawing alignment breaks. Add subtle "(best in monospace)" hint in UI.
- **Regex for markdown parsing in `markdownToUnicode`**: Keep simple. Reuse patterns from `RichTextTransformer.parseInline` where possible. Don't try to handle every edge case — 90% coverage is fine for social media use.
- **Combining characters (underline/strikethrough)**: Some platforms render these poorly (especially on mobile). Test on target platforms before shipping.
