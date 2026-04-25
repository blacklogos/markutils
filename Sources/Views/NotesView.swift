import SwiftUI
import AppKit
import ClipCore

struct NotesView: View {
    @Environment(NoteStore.self) private var store
    @State private var selectedNote: Note?
    @State private var sidebarVisible = true
    @State private var isPreview = false
    @State private var bottomMessage: String? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                toolbar
                Divider()
                HStack(spacing: 0) {
                    if sidebarVisible {
                        sidebar
                            .transition(.move(edge: .leading))
                        Divider()
                    }
                    editorPane
                }
                .animation(.easeInOut(duration: 0.18), value: sidebarVisible)
            }

            if let msg = bottomMessage {
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.toolbarBackground.opacity(0.95))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            if selectedNote == nil { selectedNote = store.todayNote }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { sidebarVisible.toggle() }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 12))
                    .foregroundStyle(sidebarVisible ? AppColors.accent : .secondary)
            }
            .buttonStyle(.plain)
            .help("Toggle sidebar")

            Button(action: createNewNote) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("New note")

            Button(action: confirmAndDeleteNote) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete note")
            .disabled(selectedNote == nil)

            Spacer()

            Button(action: copyToClipboard) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy to clipboard")
            .disabled(selectedNote == nil)

            Button(action: exportNote) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Export as .md or .txt")
            .disabled(selectedNote == nil)

            Button(action: sendToTransform) {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.right.circle")
                    Text("Transform")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Send to Transform tab")
            .disabled(selectedNote == nil)

            Divider().frame(height: 14)

            Button { isPreview.toggle() } label: {
                Text(isPreview ? "Edit" : "Preview")
                    .font(.system(size: 11))
                    .foregroundStyle(isPreview ? AppColors.accent : .secondary)
            }
            .buttonStyle(.plain)
            .help(isPreview ? "Switch to editor" : "Preview as rendered markdown")
            .disabled(selectedNote == nil)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppColors.toolbarBackground)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.notes.sorted(by: { $0.date > $1.date })) { note in
                    NoteRowView(note: note, isSelected: selectedNote?.id == note.id) {
                        selectedNote = note
                        isPreview = false
                    }
                }
            }
        }
        .frame(width: 120)
    }

    // MARK: - Editor pane

    private var editorPane: some View {
        Group {
            if let note = selectedNote {
                if isPreview {
                    CheckableHTMLPreviewView(
                        html: RichTextTransformer.markdownToHTML(note.body)
                    ) { idx, checked in
                        toggleCheckbox(in: note, at: idx, checked: checked)
                    }
                } else {
                    MarkdownTextEditor(text: Binding(
                        get: { note.body },
                        set: { newBody in
                            note.body = newBody
                            note.updatedAt = Date()
                            NoteStore.shared.save()
                        }
                    ))
                }
            } else {
                VStack {
                    Spacer()
                    Text("No note selected")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func createNewNote() {
        let currentBody = selectedNote?.body.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if currentBody.isEmpty {
            showEphemeralMessage("don't waste tree. use this note.")
            return
        }
        let note = Note()
        store.add(note)
        selectedNote = note
        isPreview = false
    }

    private func showEphemeralMessage(_ message: String) {
        withAnimation(.easeOut(duration: 0.15)) { bottomMessage = message }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.easeOut(duration: 0.3)) { bottomMessage = nil }
        }
    }

    private func confirmAndDeleteNote() {
        let alert = NSAlert()
        alert.messageText = "Delete note?"
        alert.informativeText = "This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        deleteCurrentNote()
    }

    private func deleteCurrentNote() {
        guard let note = selectedNote else { return }
        let sorted = store.notes.sorted { $0.date > $1.date }
        let idx = sorted.firstIndex(where: { $0.id == note.id })
        store.delete(note)
        if let idx {
            let fallback = sorted.indices.contains(idx) ? sorted[min(idx, sorted.count - 2)] : nil
            selectedNote = store.notes.isEmpty ? nil : fallback
        } else {
            selectedNote = store.notes.first
        }
    }

    private func copyToClipboard() {
        guard let body = selectedNote?.body else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(body, forType: .string)
    }

    private func exportNote() {
        guard let note = selectedNote else { return }
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = exportFilename(for: note)
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            try? note.body.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func sendToTransform() {
        guard let body = selectedNote?.body else { return }
        MarkdownPreviewRouter.shared.request(body)
    }

    // Finds the nth checkbox line (0-indexed) and toggles its state.
    private func toggleCheckbox(in note: Note, at index: Int, checked: Bool) {
        var lines = note.body.components(separatedBy: "\n")
        var checkboxCount = 0
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("- [ ]") || trimmed.hasPrefix("- [x]") || trimmed.hasPrefix("- [X]") else {
                continue
            }
            if checkboxCount == index {
                if checked {
                    if let r = lines[i].range(of: "- [ ]") {
                        lines[i].replaceSubrange(r, with: "- [x]")
                    }
                } else {
                    if let r = lines[i].range(of: "- [x]", options: .caseInsensitive) {
                        lines[i].replaceSubrange(r, with: "- [ ]")
                    }
                }
                break
            }
            checkboxCount += 1
        }
        note.body = lines.joined(separator: "\n")
        note.updatedAt = Date()
        NoteStore.shared.save()
    }

    private func exportFilename(for note: Note) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return "note-\(fmt.string(from: note.date)).md"
    }
}

// MARK: - Note Row

private struct NoteRowView: View {
    let note: Note
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                let preview = note.body.components(separatedBy: .newlines)
                    .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? "(empty)"
                Text(preview)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AppColors.accent : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(dateLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isSelected ? AppColors.accent.opacity(0.12) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var dateLabel: String {
        if Calendar.current.isDateInToday(note.date) { return "Today" }
        if Calendar.current.isDateInYesterday(note.date) { return "Yesterday" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: note.date)
    }
}
