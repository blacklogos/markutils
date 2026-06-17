import SwiftUI

// The capture card shown when the Creator triggers "Comment" on a selection.
// Shows the captured quote as a read-only readback (R2) above a note field;
// Save is disabled until the note has content so no blank comment is created.
struct CommentCapturePopover: View {
    let quote: String
    @Binding var note: String
    let onSave: () -> Void
    let onCancel: () -> Void

    @FocusState private var noteFocused: Bool

    private var canSave: Bool {
        !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Commenting on")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("“\(quote)”")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.accent.opacity(0.10)))

            ZStack(alignment: .topLeading) {
                if note.isEmpty {
                    Text("What should change here?")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $note)
                    .font(.system(size: 12))
                    .frame(height: 72)
                    .scrollContentBackground(.hidden)
                    .focused($noteFocused)
            }
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(AppColors.divider))

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(12)
        .frame(width: 290)
        .onAppear { noteFocused = true }
    }
}
