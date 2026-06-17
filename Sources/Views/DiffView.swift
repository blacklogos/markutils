import SwiftUI
import ClipCore

// Diff tab (⌘6): paste two markdown texts and see a live line-level unified diff.
// Pairs with the Reader's "Copy for AI" loop — paste the original on the left and
// the agent's revised version on the right to review exactly what changed.
struct DiffView: View {
    @State private var original = ""
    @State private var revised = ""

    // Bound the LCS table — it is O(lines² ); pathological inputs would hang the
    // main thread. Realistic markdown stays well under this.
    private let maxLines = 4000

    var body: some View {
        let over = lineCount(original) > maxLines || lineCount(revised) > maxLines
        let lines = over ? [] : TextDiff.diff(original, revised)

        VStack(spacing: 0) {
            header(lines: lines, tooLarge: over)
            VSplitView {
                HSplitView {
                    editorPane(title: "Original", text: $original,
                               placeholder: "Paste the original text…")
                    editorPane(title: "Revised", text: $revised,
                               placeholder: "Paste the revised text…")
                }
                .frame(minHeight: 120)

                HTMLPreviewView(htmlContent: over ? tooLargeHTML : DiffHTMLRenderer.html(for: lines))
                    .frame(minHeight: 120)
            }
        }
        .background(AppColors.windowBackground)
    }

    // MARK: - Header

    private func header(lines: [TextDiff.Line], tooLarge: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "plusminus")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.accent)
            Text("Compare")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)

            if !tooLarge {
                let added = lines.filter { $0.kind == .added }.count
                let removed = lines.filter { $0.kind == .removed }.count
                if added > 0 || removed > 0 {
                    Text("+\(added)")
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(.green)
                    Text("−\(removed)")
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(.red)
                }
            }

            Spacer()

            headerButton(icon: "arrow.left.arrow.right", tooltip: "Swap sides") {
                swap(&original, &revised)
            }
            headerButton(icon: "xmark.circle", tooltip: "Clear both") {
                original = ""; revised = ""
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(AppColors.toolbarBackground)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(AppColors.divider), alignment: .bottom)
    }

    private func headerButton(icon: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    // MARK: - Editor pane

    private func editorPane(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(AppColors.toolbarBackground)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(AppColors.divider), alignment: .bottom)

            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: text)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(4)
            }
            .background(AppColors.editorBackground)
        }
    }

    // MARK: - Helpers

    private func lineCount(_ s: String) -> Int {
        s.isEmpty ? 0 : s.reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
    }

    private var tooLargeHTML: String {
        MarkdownPreviewStyle.page(
            body: "<div class=\"diff-empty\">Too large to diff line-by-line "
                + "(over \(maxLines) lines per side).</div>")
    }
}
