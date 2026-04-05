import SwiftUI

// Displays word count, character count, and cursor position for text-editing tabs.
// Pass cursorRange: nil to hide the Ln/Col segment.
struct StatusBarView: View {
    let text: String
    let cursorRange: NSRange?

    private var wordCount: Int {
        text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }

    // Unicode scalar count (consistent with character editor expectations)
    private var charCount: Int { text.unicodeScalars.count }

    private var lineCol: (line: Int, col: Int)? {
        guard let range = cursorRange else { return nil }
        let nsText = text as NSString
        let loc = min(range.location, nsText.length)
        let prefix = nsText.substring(to: loc)
        let lines = prefix.components(separatedBy: "\n")
        return (lines.count, (lines.last?.count ?? 0) + 1)
    }

    var body: some View {
        HStack(spacing: 0) {
            Text("\(wordCount) words  •  \(charCount) chars")
                .monospacedDigit()

            if let (line, col) = lineCol {
                Text("  •  Ln \(line), Col \(col)")
                    .monospacedDigit()
            }

            Spacer()
        }
        .font(.system(size: 11))
        .foregroundStyle(AppColors.textSecondary)
        .padding(.horizontal, 12)
        .frame(height: 22)
        .background(AppColors.toolbarBackground)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundStyle(AppColors.divider),
            alignment: .top
        )
    }
}
