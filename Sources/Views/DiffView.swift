import SwiftUI
import ClipCore

// Diff tab (⌘6): paste two markdown texts and see a live line-level unified diff.
// Pairs with the Reader's "Copy for AI" loop — paste the original on the left and
// the agent's revised version on the right to review exactly what changed.
struct DiffView: View {
    @State private var original = ""
    @State private var revised = ""
    @State private var precision: TextDiff.Precision = .smart

    // Bound the LCS table — it is O(lines² ); pathological inputs would hang the
    // main thread. Realistic markdown stays well under this.
    private let maxLines = 4000

    var body: some View {
        let over = lineCount(original) > maxLines || lineCount(revised) > maxLines
        let lines = over ? [] : TextDiff.annotatedDiff(original, revised, precision: precision)

        VStack(spacing: 0) {
            header()
            VSplitView {
                HSplitView {
                    editorPane(title: "Original", text: $original,
                               placeholder: "Paste the original text…")
                    editorPane(title: "Revised", text: $revised,
                               placeholder: "Paste the revised text…")
                }
                .frame(minHeight: 120)

                HTMLPreviewView(htmlContent: over
                    ? tooLargeHTML
                    : DiffHTMLRenderer.html(for: lines, original: original, revised: revised))
                    .frame(minHeight: 120)
            }
        }
        .background(AppColors.windowBackground)
    }

    // MARK: - Header

    private func header() -> some View {
        HStack(spacing: 8) {
            Image(systemName: "plusminus")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.accent)
            Text("Compare")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)

            // Removal/addition counts live in the preview's pane headers now.
            Spacer()

            // Diff precision: how finely changed line pairs are highlighted
            Picker("", selection: $precision) {
                Text("Smart").tag(TextDiff.Precision.smart)
                Text("Line").tag(TextDiff.Precision.line)
                Text("Word").tag(TextDiff.Precision.word)
                Text("Char").tag(TextDiff.Precision.character)
            }
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(width: 90)
            .help("Highlight precision inside changed lines")

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

    // Body fragment — HTMLPreviewView wraps it in the page envelope.
    private var tooLargeHTML: String {
        "<div class=\"diff-empty\">Too large to diff line-by-line "
            + "(over \(maxLines) lines per side).</div>"
    }
}
