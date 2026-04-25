import SwiftUI
import AppKit
import ClipCore

// Minimal floating note canvas.
// Layout: ZStack(rounded bg) → VStack(38px topBar + flex editor/search + 28px bottomBar)
//   + ephemeral bottom message overlay.
// Hover zones: onHover on the bar container — stays visible while cursor is anywhere in strip.
// Show is immediate; hide fades out (0.15s).
struct MinimalNotesView: View {
    @Environment(NoteStore.self) private var store
    var onClose:    (() -> Void)? = nil
    var onMinimize: (() -> Void)? = nil
    var onZoom:     (() -> Void)? = nil

    @AppStorage("appTheme") private var appTheme: String = "System"

    @State private var selectedNote: Note?
    @State private var topHovered    = false
    @State private var bottomHovered = false
    @State private var showSearch    = false
    @State private var searchQuery   = ""
    @State private var isPreview     = false
    @State private var bottomMessage: String? = nil

    private var preferredColorScheme: ColorScheme? {
        switch appTheme {
        case "Light": return .light
        case "Dark":  return .dark
        default:      return nil
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                topBar
                mainContent
                bottomBar
            }

            // Ephemeral "don't waste tree" message
            if let msg = bottomMessage {
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // Rounded canvas matching main window style
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .preferredColorScheme(preferredColorScheme)
        .onAppear { if selectedNote == nil { selectedNote = store.todayNote } }
        // ⌘N: new note with empty-note guard (only active in this panel)
        .background(
            Button("") { createNewNote() }
                .keyboardShortcut("n", modifiers: .command)
                .hidden()
        )
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        if showSearch {
            searchList
        } else {
            editorCanvas
        }
    }

    private var editorCanvas: some View {
        Group {
            if let note = selectedNote {
                if isPreview {
                    CheckableHTMLPreviewView(
                        html: RichTextTransformer.markdownToHTML(note.body)
                    ) { idx, checked in toggleCheckbox(in: note, at: idx, checked: checked) }
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
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Top bar (38px, immediate show / quick-fade hide)

    private var topBar: some View {
        HStack(spacing: 8) {
            trafficLights.padding(.leading, 12)

            if showSearch {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { showSearch = false }
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                TextField("Search…", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.trailing, 12)
            } else {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { showSearch = true }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Search notes")

                Button(action: createNewNote) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("New note (⌘N)")

                Spacer()

                Button { isPreview.toggle() } label: {
                    Text(isPreview ? "Edit" : "Preview")
                        .font(.system(size: 10))
                        .foregroundStyle(isPreview ? AppColors.accent : .secondary)
                }
                .buttonStyle(.plain)

                Button(action: copyToClipboard) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")

                Button(action: exportNote) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Export")
                .padding(.trailing, 12)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 38)
        .background(topHovered || showSearch ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.clear))
        .opacity(topHovered || showSearch ? 1 : 0)
        .onHover { hovering in
            if hovering { topHovered = true }
            else { withAnimation(.easeOut(duration: 0.15)) { topHovered = false } }
        }
    }

    // Custom traffic light dots (native buttons are hidden in NotesPanel)
    private var trafficLights: some View {
        HStack(spacing: 6) {
            Circle().fill(Color(nsColor: .systemRed)).frame(width: 12, height: 12)
                .onTapGesture { onClose?() }
            Circle().fill(Color(nsColor: .systemYellow)).frame(width: 12, height: 12)
                .onTapGesture { onMinimize?() }
            Circle().fill(Color(nsColor: .systemGreen)).frame(width: 12, height: 12)
                .onTapGesture { onZoom?() }
        }
    }

    // MARK: - Bottom bar (28px, immediate show / quick-fade hide)

    private var bottomBar: some View {
        HStack(spacing: 10) {
            // Prev / Next navigation
            Button { selectAdjacentNote(offset: +1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(hasPrev ? .secondary : Color.secondary.opacity(0.3))
            }
            .buttonStyle(.plain)
            .disabled(!hasPrev)
            .help("Older note")

            Button { selectAdjacentNote(offset: -1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(hasNext ? .secondary : Color.secondary.opacity(0.3))
            }
            .buttonStyle(.plain)
            .disabled(!hasNext)
            .help("Newer note")

            // Jump to the very first (newest) note
            Button { selectedNote = sortedNotes.first; isPreview = false } label: {
                Image(systemName: "arrow.up.to.line")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(sortedNotes.first?.id == selectedNote?.id
                                     ? Color.secondary.opacity(0.3) : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(sortedNotes.first?.id == selectedNote?.id)
            .help("First note")

            Spacer()

            if let note = selectedNote {
                let words = note.body.split(whereSeparator: \.isWhitespace).count
                Text("\(words) words · \(editedLabel(note))")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Delete current note
            Button(action: confirmAndDeleteNote) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete note")
            .padding(.trailing, 12)
        }
        .padding(.leading, 12)
        .frame(maxWidth: .infinity, minHeight: 28)
        .background(bottomHovered ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.clear))
        .opacity(bottomHovered ? 1 : 0)
        .onHover { hovering in
            if hovering { bottomHovered = true }
            else { withAnimation(.easeOut(duration: 0.15)) { bottomHovered = false } }
        }
    }

    // MARK: - Search list

    private var searchList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredNotes) { note in
                    searchRow(note)
                    Divider().padding(.horizontal, 12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func searchRow(_ note: Note) -> some View {
        Button {
            selectedNote = note
            withAnimation(.easeOut(duration: 0.15)) { showSearch = false }
            searchQuery = ""
            isPreview = false
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                let preview = note.body
                    .components(separatedBy: .newlines)
                    .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? "(empty)"
                Text(preview)
                    .font(.system(size: 11, weight: selectedNote?.id == note.id ? .semibold : .regular))
                    .foregroundStyle(selectedNote?.id == note.id ? AppColors.accent : .primary)
                    .lineLimit(2)
                Text(metaLabel(note))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selectedNote?.id == note.id ? AppColors.accent.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Navigation helpers

    private var sortedNotes: [Note] { store.notes.sorted { $0.date > $1.date } }

    private var filteredNotes: [Note] {
        guard !searchQuery.isEmpty else { return sortedNotes }
        return sortedNotes.filter { $0.body.localizedCaseInsensitiveContains(searchQuery) }
    }

    private var currentIndex: Int? {
        sortedNotes.firstIndex(where: { $0.id == selectedNote?.id })
    }

    // sortedNotes[0] = newest; higher index = older
    private var hasPrev: Bool { (currentIndex ?? 0) < sortedNotes.count - 1 }
    private var hasNext: Bool { (currentIndex ?? 0) > 0 }

    private func selectAdjacentNote(offset: Int) {
        guard let idx = currentIndex else { return }
        let target = idx + offset
        guard sortedNotes.indices.contains(target) else { return }
        selectedNote = sortedNotes[target]
        isPreview = false
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

    // NSAlert works reliably on nonactivating panels — SwiftUI .alert() does not.
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
        let sorted = sortedNotes
        let idx = sorted.firstIndex(where: { $0.id == note.id })
        store.delete(note)
        // Select adjacent note after deletion
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
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        panel.nameFieldStringValue = "note-\(fmt.string(from: note.date)).md"
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            try? note.body.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Labels

    // "Apr 25 · 11:38 PM"
    private func metaLabel(_ note: Note) -> String {
        let d = DateFormatter(); d.dateFormat = "MMM d"
        let t = DateFormatter(); t.dateFormat = "h:mm a"
        return "\(d.string(from: note.date)) · \(t.string(from: note.updatedAt))"
    }

    // "Today at 11:38 PM" / "Yesterday at …" / "Apr 24 at …"
    private func editedLabel(_ note: Note) -> String {
        let t = DateFormatter(); t.dateFormat = "h:mm a"
        let time = t.string(from: note.updatedAt)
        if Calendar.current.isDateInToday(note.date)     { return "Today at \(time)" }
        if Calendar.current.isDateInYesterday(note.date) { return "Yesterday at \(time)" }
        let d = DateFormatter(); d.dateFormat = "MMM d"
        return "\(d.string(from: note.date)) at \(time)"
    }

    // MARK: - Checkbox toggle

    private func toggleCheckbox(in note: Note, at index: Int, checked: Bool) {
        var lines = note.body.components(separatedBy: "\n")
        var count = 0
        for (i, line) in lines.enumerated() {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("- [ ]") || t.hasPrefix("- [x]") || t.hasPrefix("- [X]") else { continue }
            if count == index {
                if checked, let r = lines[i].range(of: "- [ ]") { lines[i].replaceSubrange(r, with: "- [x]") }
                else if !checked, let r = lines[i].range(of: "- [x]", options: .caseInsensitive) { lines[i].replaceSubrange(r, with: "- [ ]") }
                break
            }
            count += 1
        }
        note.body = lines.joined(separator: "\n")
        note.updatedAt = Date()
        NoteStore.shared.save()
    }
}
