import SwiftUI

struct SnippetsView: View {
    @Environment(SnippetStore.self) private var store
    @State private var searchText = ""
    @State private var showEditor = false
    @State private var editingSnippet: Snippet? = nil

    private var filteredSnippets: [Snippet] {
        guard !searchText.isEmpty else { return store.snippets }
        let q = searchText.lowercased()
        return store.snippets.filter {
            $0.name.lowercased().contains(q) || $0.content.lowercased().contains(q)
        }
    }

    private var builtIns: [Snippet] { filteredSnippets.filter { $0.isBuiltIn } }
    private var custom: [Snippet] { filteredSnippets.filter { !$0.isBuiltIn } }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Snippets")
                    .font(.headline)
                Spacer()
                Button(action: { editingSnippet = nil; showEditor = true }) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
                .help("New snippet")
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search snippets…", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor)))
            .padding(.horizontal)
            .padding(.bottom, 6)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !builtIns.isEmpty {
                        sectionHeader("Templates")
                        ForEach(builtIns) { snippet in
                            SnippetRowView(snippet: snippet) {
                                editingSnippet = snippet
                                showEditor = true
                            }
                            Divider().padding(.leading, 36)
                        }
                    }

                    if !custom.isEmpty {
                        sectionHeader("My Snippets")
                        ForEach(custom) { snippet in
                            SnippetRowView(snippet: snippet) {
                                editingSnippet = snippet
                                showEditor = true
                            }
                            Divider().padding(.leading, 36)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .overlay {
                if store.snippets.isEmpty {
                    ContentUnavailableView("No Snippets", systemImage: "doc.text", description: Text("Tap + to create your first snippet."))
                } else if filteredSnippets.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            SnippetEditorView(snippet: editingSnippet) { saved in
                if let existing = editingSnippet {
                    existing.name = saved.name
                    existing.content = saved.content
                    existing.category = saved.category
                    store.snippets = store.snippets // trigger save
                } else {
                    store.add(saved)
                }
                showEditor = false
                editingSnippet = nil
            } onCancel: {
                showEditor = false
                editingSnippet = nil
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Snippet Row

struct SnippetRowView: View {
    let snippet: Snippet
    let onEdit: () -> Void

    @Environment(SnippetStore.self) private var store
    @State private var isHovering = false
    @State private var showCopied = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: snippet.isBuiltIn ? "doc.text.fill" : "doc.text")
                .foregroundStyle(snippet.isBuiltIn ? .blue : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(snippet.name)
                    .font(.body)
                    .lineLimit(1)
                Text(snippet.content.prefix(60).replacingOccurrences(of: "\n", with: " "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovering {
                HStack(spacing: 8) {
                    Button(action: copySnippet) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(showCopied ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy to clipboard")

                    if !snippet.isBuiltIn {
                        Button(action: { store.delete(snippet) }) {
                            Image(systemName: "trash")
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .help("Delete")
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(isHovering ? Color.secondary.opacity(0.07) : Color.clear)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Copy", action: copySnippet)
            Button("Duplicate") { store.duplicate(snippet) }
            if !snippet.isBuiltIn {
                Button("Edit") { onEdit() }
                Divider()
                Button("Delete", role: .destructive) { store.delete(snippet) }
            }
        }
        .onTapGesture { copySnippet() }
    }

    private func copySnippet() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet.content, forType: .string)
        withAnimation { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopied = false }
        }
    }
}

// MARK: - Snippet Editor Sheet

struct SnippetEditorView: View {
    let snippet: Snippet?
    let onSave: (Snippet) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var content: String
    @State private var category: String

    init(snippet: Snippet?, onSave: @escaping (Snippet) -> Void, onCancel: @escaping () -> Void) {
        self.snippet = snippet
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: snippet?.name ?? "")
        _content = State(initialValue: snippet?.content ?? "")
        _category = State(initialValue: snippet?.category ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(snippet == nil ? "New Snippet" : "Edit Snippet")
                    .font(.headline)
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Button("Save") {
                    let s = Snippet(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        content: content,
                        category: category.isEmpty ? nil : category,
                        isBuiltIn: false
                    )
                    onSave(s)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name").font(.caption).foregroundStyle(.secondary)
                    TextField("Snippet name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Category (optional)").font(.caption).foregroundStyle(.secondary)
                    TextField("e.g. Templates, Email", text: $category)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Content").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $content)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minHeight: 200)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(NSColor.separatorColor)))
                }
            }
            .padding()
        }
        .frame(width: 480, height: 420)
    }
}
