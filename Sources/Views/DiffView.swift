import SwiftUI
import ClipCore

// Diff tab (⌘6): paste two markdown texts and see a live line-level unified diff.
// Pairs with the Reader's "Copy for AI" loop — paste the original on the left and
// the agent's revised version on the right to review exactly what changed.
struct DiffView: View {
    @State private var original = ""
    @State private var revised = ""
    @State private var precision: TextDiff.Precision = .smart

    // Diff + HTML are computed off-main with a short debounce (never in body):
    // the LCS is O(changed-region²) and HTML assembly is linear in output size.
    @State private var previewHTML = DiffView.computeHTML("", "", .smart)
    @State private var diffTask: Task<Void, Never>?

    // Bound the LCS table; pathological inputs would still burn CPU off-main.
    // Realistic markdown stays well under this.
    private nonisolated static let maxLines = 4000

    var body: some View {
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

                HTMLPreviewView(htmlContent: previewHTML)
                    .frame(minHeight: 120)
            }
        }
        .background(AppColors.windowBackground)
        .onChange(of: original) { scheduleDiff() }
        .onChange(of: revised) { scheduleDiff() }
        .onChange(of: precision) { scheduleDiff() }
    }

    // MARK: - Diff computation (debounced, off-main)

    private func scheduleDiff() {
        diffTask?.cancel()
        let o = original, r = revised, p = precision
        diffTask = Task {
            // Debounce: coalesce keystrokes; cancellation aborts stale runs.
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let html = await Task.detached(priority: .userInitiated) {
                DiffView.computeHTML(o, r, p)
            }.value
            guard !Task.isCancelled else { return }
            previewHTML = html
        }
    }

    // nonisolated: runs inside Task.detached, off the main actor by design.
    private nonisolated static func computeHTML(_ original: String, _ revised: String,
                                                _ precision: TextDiff.Precision) -> String {
        guard TextDiff.lineCount(original) <= maxLines,
              TextDiff.lineCount(revised) <= maxLines else {
            return "<div class=\"diff-empty\">Too large to diff line-by-line "
                + "(over \(maxLines) lines per side).</div>"
        }
        let lines = TextDiff.annotatedDiff(original, revised, precision: precision)
        return DiffHTMLRenderer.html(for: lines, original: original, revised: revised)
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
}
