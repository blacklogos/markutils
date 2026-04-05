---
module: Clip
date: 2026-04-05
problem_type: best_practice
component: tooling
symptoms:
  - "String literal Unicode character maps are fragile and hard to verify (e.g., 𝐚𝐛𝐜...)"
  - "Copy-paste errors introduce wrong characters silently — map produces wrong output"
  - "Some Unicode ranges have gaps (unassigned scalars) that break sequential string literals"
root_cause: wrong_api
resolution_type: code_fix
severity: medium
tags: [unicode, swift, character-map, unicode-scalar, social-media-formatter]
---

# Best Practice: Unicode Character Maps via Scalar Arithmetic in Swift

## Problem

When building Unicode style formatters (bold/italic/monospace/script for social media), the naive approach
uses string literal character maps:

```swift
let normal = "abcdefghijklmnopqrstuvwxyz"
let bold   = "𝐚𝐛𝐜𝐝𝐞𝐟𝐠𝐡𝐢𝐣𝐤𝐥𝐦𝐧𝐨𝐩𝐪𝐫𝐬𝐭𝐮𝐯𝐰𝐱𝐲𝐳"
```

This approach is fragile:
- Hard to verify visually (supplementary-plane chars look similar or invisible)
- Silent wrong-character bugs if one glyph is off by one code point
- Breaks entirely when the Unicode range has gaps (unassigned scalar slots)

## Environment

- Module: Clip (macOS menu bar utility)
- Language: Swift 5.9, macOS 14+
- Affected Component: `Sources/Utilities/UnicodeTextFormatter.swift`
- Date: 2026-04-05

## Symptoms

- Characters in the "Mathematical Script" Unicode range have gaps: e.g., U+1D4BA (script e) is
  **unassigned** — the correct scalar is U+212F (ℯ) in the BMP. Sequential string literals silently
  skip or mismap these positions.
- Math Italic Small h maps to U+210E (ℎ), not U+1D44E+7. A plain string gives wrong char.
- Copy-paste errors across bold/italic/boldItalic string literals were impossible to audit visually.

## What Didn't Work

**Attempted: String literal maps (existing pattern in codebase)**
- `let bold = "𝐚𝐛𝐜𝐝..."` etc.
- **Why it failed:** Unverifiable visually; Script range has unassigned gaps; any single wrong char is
  a silent bug.

## Solution

Use programmatic scalar arithmetic + explicit exception dictionaries for ranges with gaps:

```swift
// Regular ranges (no gaps): generate via arithmetic
private static let boldMap: [Character: Character] = {
    var map: [Character: Character] = [:]
    for i in 0..<26 {
        map[Character(Unicode.Scalar(0x61 + i)!)] = Character(Unicode.Scalar(0x1D41A + i)!) // a-z
        map[Character(Unicode.Scalar(0x41 + i)!)] = Character(Unicode.Scalar(0x1D400 + i)!) // A-Z
    }
    for i in 0..<10 {
        map[Character(Unicode.Scalar(0x30 + i)!)] = Character(Unicode.Scalar(0x1D7CE + i)!) // 0-9
    }
    return map
}()

// Ranges with gaps: use explicit offset→scalar dictionaries
private static let scriptMap: [Character: Character] = {
    // Capital exceptions (some slots in U+1D49C range are unassigned → use BMP fallbacks)
    let upperBMP: [Int: UInt32] = [
        1: 0x212C, // B → ℬ
        4: 0x2130, // E → ℰ
        5: 0x2131, // F → ℱ
        7: 0x210B, // H → ℋ
        8: 0x2110, // I → ℐ
        11: 0x2112, // L → ℒ
        12: 0x2133, // M → ℳ
        17: 0x211B, // R → ℛ
    ]
    // Lowercase: explicit mapping because e(212F), g(210A), o(2134) break the sequence
    let lowerExact: [Int: UInt32] = [
        0: 0x1D4B6, 1: 0x1D4B7, 2: 0x1D4B8, 3: 0x1D4B9,
        4: 0x212F,  // e → ℯ (not U+1D4BA, unassigned)
        5: 0x1D4BB, 6: 0x210A,  // g → ℊ (not U+1D4BC, unassigned)
        7: 0x1D4BD, 8: 0x1D4BE, 9: 0x1D4BF,
        10: 0x1D4C0, 11: 0x1D4C1, 12: 0x1D4C2, 13: 0x1D4C3,
        14: 0x2134, // o → ℴ (not U+1D4C4, unassigned)
        15: 0x1D4C5, /* ... rest sequential */ 25: 0x1D4CF
    ]
    var map: [Character: Character] = [:]
    for i in 0..<26 {
        let to = upperBMP[i] ?? (0x1D49C + UInt32(i))
        map[Character(Unicode.Scalar(0x41 + i)!)] = Character(Unicode.Scalar(to)!)
    }
    for (i, to) in lowerExact {
        map[Character(Unicode.Scalar(0x61 + i)!)] = Character(Unicode.Scalar(to)!)
    }
    return map
}()
```

Apply a style:
```swift
static func apply(_ style: Style, to text: String) -> String {
    switch style {
    case .bold: return text.map { boldMap[$0].map(String.init) ?? String($0) }.joined()
    // ...
    }
}
```

Revert (reverse map built automatically):
```swift
private static let reverseMap: [Character: Character] = {
    var map: [Character: Character] = [:]
    for fwd in [boldMap, italicMap, boldItalicMap, monospaceMap, scriptMap, smallCapsMap] {
        for (plain, styled) in fwd { map[styled] = plain }
    }
    return map
}()
```

## Why This Works

1. **Scalar arithmetic** generates provably correct mappings — no copy-paste risk.
2. **Exception dictionaries** handle BMP fallbacks and unassigned gaps explicitly,
   with comments citing the Unicode standard reason.
3. **Reverse map** is derived automatically from forward maps — never gets out of sync.
4. Swift `static let` with closure initializer = lazy, computed once, zero cost at call site.

## Prevention

- Never use raw string literals for supplementary-plane Unicode char maps in Swift.
- Always verify Unicode ranges in the standard (https://unicode.org/charts/PDF/U1D400.pdf)
  for unassigned slots before building a sequential map.
- Use `Unicode.Scalar(value)` — it returns `nil` for unassigned code points, making gaps
  compile-time visible if forced-unwrapped.

## Related Issues

No related issues documented yet.
