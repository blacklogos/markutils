import SwiftUI
import ClipCore

// Side panel listing the open document's comments. Selecting a row jumps the
// preview to (and flashes) the anchor (R9, panel→preview); rows support inline
// note edit and delete. Lives outside the WebView, so it adds no XSS surface.
struct CommentSidePanel: View {
    let comments: [Comment]
    @Binding var selectedID: UUID?
    let onJump: (UUID) -> Void
    let onEdit: (UUID, String) -> Void
    let onDelete: (Comment) -> Void
    let onClearAll: () -> Void

    @State private var showClearConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.accent)
                Text("COMMENTS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("\(comments.count)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                if !comments.isEmpty {
                    Button { showClearConfirm = true } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Clear all comments")
                    .confirmationDialog(
                        "Clear all \(comments.count) comment\(comments.count == 1 ? "" : "s")?",
                        isPresented: $showClearConfirm, titleVisibility: .visible
                    ) {
                        Button("Clear all", role: .destructive, action: onClearAll)
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This removes every comment for this file. The document itself is untouched.")
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(AppColors.toolbarBackground)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(AppColors.divider), alignment: .bottom)

            if comments.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "highlighter")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("Select text in the document\nto leave a comment.")
                        .font(.system(size: 11))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(comments) { comment in
                            CommentRowView(
                                comment: comment,
                                isSelected: selectedID == comment.id,
                                onTap: { selectedID = comment.id; onJump(comment.id) },
                                onEdit: { onEdit(comment.id, $0) },
                                onDelete: { onDelete(comment) }
                            )
                        }
                    }
                    .padding(6)
                }
            }
        }
        .frame(width: 230)
        .background(AppColors.editorBackground)
    }
}

private struct CommentRowView: View {
    let comment: Comment
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: (String) -> Void
    let onDelete: () -> Void

    @State private var isEditing = false
    @State private var draft = ""
    @State private var isHovering = false
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                if comment.status == .needsReview {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                        .help("This quote no longer matches the document")
                }
                Text("“\(comment.quote)”")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isHovering || isEditing {
                    Button {
                        if isEditing { onEdit(draft) }
                        isEditing.toggle()
                    } label: {
                        Image(systemName: isEditing ? "checkmark" : "pencil")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help(isEditing ? "Save note" : "Edit note")

                    Button { showDeleteConfirm = true } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Delete comment")
                    .confirmationDialog("Delete this comment?",
                                        isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                        Button("Delete", role: .destructive, action: onDelete)
                        Button("Cancel", role: .cancel) {}
                    }
                }
            }

            if isEditing {
                TextField("Note", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .lineLimit(1...5)
                    .onSubmit { onEdit(draft); isEditing = false }
            } else {
                Text(comment.note)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? AppColors.activeTab : AppColors.toolbarBackground.opacity(0.5))
        )
        .contentShape(Rectangle())   // full-row hit area (clear-background fix)
        .onTapGesture { if !isEditing { onTap() } }
        .onHover { isHovering = $0 }
        .onChange(of: isEditing) { _, editing in
            if editing { draft = comment.note }
        }
    }
}
