import SwiftUI
import AppKit
import ClipCore

// Minimal floating note canvas.
// Layout: VStack with 38px top zone + flex editor + 28px bottom zone.
// Each zone reveals its content only while the cursor is within that strip.
// onHover on the HStack container ensures the bar stays visible when cursor
// moves from empty space to a button inside it — no flicker, no auto-dismiss.
struct MinimalNotesView: View {
    @Environment(NoteStore.self) private var store
    var onClose: (() -> Void)? = nil

    @State private var selectedNote: Note?
    @State private var topHovered = false
    @State private var bottomHovered = false
    @State private var showSearch = false
    @State private var searchQuery = ""
    @State private var isPreview = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            mainContent
            bottomBar
        }
        .onAppear { if selectedNote == nil { selectedNote = store.todayNote } }
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
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Top bar (38px, hover-reveal)

    private var topBar: some View {
        HStack(spacing: 8) {
            trafficLights
                .padding(.leading, 12)

            if showSearch {
                // Search mode: X to exit + text field fills remaining space
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { showSearch = false }
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
                // Normal mode: glass + spacer + actions
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { showSearch = true }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Search notes")

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
        // onHover on the container — stays true even when cursor moves to child buttons
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { topHovered = hovering }
        }
        .background(topHovered || showSearch ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.clear))
        .opacity(topHovered || showSearch ? 1 : 0)
    }

    private var trafficLights: some View {
        HStack(spacing: 6) {
            Circle().fill(Color(nsColor: .systemRed)).frame(width: 12, height: 12)
                .onTapGesture { onClose?() }
            Circle().fill(Color(nsColor: .systemYellow)).frame(width: 12, height: 12)
            Circle().fill(Color(nsColor: .systemGreen)).frame(width: 12, height: 12)
        }
    }

    // MARK: - Bottom bar (28px, hover-reveal)

    private var bottomBar: some View {
        HStack {
            if let note = selectedNote {
                let words = note.body.split(whereSeparator: \.isWhitespace).count
                Text("\(words) words")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let note = selectedNote {
                Text(editedLabel(note))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 28)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { bottomHovered = hovering }
        }
        .background(bottomHovered ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.clear))
        .opacity(bottomHovered ? 1 : 0)
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
            withAnimation(.easeInOut(duration: 0.15)) { showSearch = false }
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
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var filteredNotes: [Note] {
        let sorted = store.notes.sorted { $0.date > $1.date }
        guard !searchQuery.isEmpty else { return sorted }
        return sorted.filter { $0.body.localizedCaseInsensitiveContains(searchQuery) }
    }

    // "Apr 24 · 7:02 PM"
    private func metaLabel(_ note: Note) -> String {
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "MMM d"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mm a"
        return "\(dayFmt.string(from: note.date)) · \(timeFmt.string(from: note.updatedAt))"
    }

    // "Today at 7:02 PM" / "Yesterday at …" / "Apr 24 at …"
    private func editedLabel(_ note: Note) -> String {
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mm a"
        let time = timeFmt.string(from: note.updatedAt)
        if Calendar.current.isDateInToday(note.date) { return "Today at \(time)" }
        if Calendar.current.isDateInYesterday(note.date) { return "Yesterday at \(time)" }
        let dayFmt = DateFormatter(); dayFmt.dateFormat = "MMM d"
        return "\(dayFmt.string(from: note.date)) at \(time)"
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
