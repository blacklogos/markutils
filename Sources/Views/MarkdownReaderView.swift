import SwiftUI
import UniformTypeIdentifiers
import AppKit
import ClipCore

// Reader tab: view markdown files and folders rendered with the app's
// preview styling. Files arrive via the open buttons, drag-and-drop,
// Finder "Open With Clip", or the recents list.
struct MarkdownReaderView: View {
    @State private var store = MarkdownDocumentStore.shared
    @State private var commentStore = CommentStore.shared
    @State private var showSidebar = true
    @State private var showComments = true
    @State private var showCopied = false
    @State private var isDropTargeted = false

    // Capture flow: a pending selection drives the capture popover.
    @State private var pendingSelection: PendingSelection?
    @State private var captureNote = ""
    @State private var selectedCommentID: UUID?
    @State private var flashAnchorID: UUID?

    var body: some View {
        Group {
            if store.currentFileURL == nil && store.fileTree.isEmpty {
                emptyState
            } else {
                documentLayout
            }
        }
        .background(AppColors.windowBackground)
        .overlay(dropHighlight)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        // Standard document shortcuts, scoped to the Reader tab.
        .background(Button("") { Self.presentOpenDialog(directories: false) }
            .keyboardShortcut("o", modifiers: .command).hidden())
        .background(Button("") { Self.presentOpenDialog(directories: true) }
            .keyboardShortcut("o", modifiers: [.command, .shift]).hidden())
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                Image(systemName: "book.pages")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(AppColors.accent.opacity(0.8))

                VStack(spacing: 4) {
                    Text("Markdown Reader")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Open a file or folder — or drop it anywhere here.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                // ⌘O / ⌘⇧O are registered once, on the view root — these
                // buttons are the visible affordance for the same actions.
                HStack(spacing: 10) {
                    Button("Open File…") { Self.presentOpenDialog(directories: false) }
                    Button("Open Folder…") { Self.presentOpenDialog(directories: true) }
                }
                .controlSize(.regular)

                if let error = store.loadError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 2)
                }
            }

            if !store.recentURLs.isEmpty {
                recentsList
                    .padding(.top, 28)
            }

            Spacer()
            Spacer() // bias content slightly above center
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recentsList: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("RECENT")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.leading, 8)
                .padding(.bottom, 4)

            ForEach(store.recentURLs, id: \.self) { url in
                Button {
                    store.open(url: url)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: url.hasDirectoryPath ? "folder" : "doc.text")
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.accent)
                            .frame(width: 14)
                        Text(url.lastPathComponent)
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(1)
                        Text(url.deletingLastPathComponent().path.abbreviatingHome)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(url.path)
            }
        }
        .frame(maxWidth: 300, alignment: .leading)
    }

    // MARK: - Document layout

    private var documentLayout: some View {
        HStack(spacing: 0) {
            if (!store.fileTree.isEmpty || store.isScanning) && showSidebar {
                sidebar
                    .frame(width: 190)
                Divider()
            }

            VStack(spacing: 0) {
                previewHeader
                if let error = store.loadError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.08))
                }
                previewArea
            }

            if store.currentFileURL != nil && showComments {
                Divider()
                CommentSidePanel(
                    comments: commentStore.comments,
                    selectedID: $selectedCommentID,
                    onJump: { jump(to: $0) },
                    onEdit: { commentStore.updateNote(id: $0, note: $1) },
                    onDelete: { commentStore.delete($0) }
                )
            }
        }
    }

    @ViewBuilder
    private var previewArea: some View {
        if store.currentFileURL != nil {
            AnnotatableHTMLPreviewView(
                html: store.renderedHTML,
                comments: commentStore.comments,
                flashAnchorID: flashAnchorID,
                onSelect: { quote, prefix, suffix in
                    captureNote = ""
                    pendingSelection = PendingSelection(quote: quote, prefix: prefix, suffix: suffix)
                },
                onCommentClicked: { selectedCommentID = $0 }
            )
            .popover(item: $pendingSelection, arrowEdge: .top) { selection in
                CommentCapturePopover(
                    quote: selection.quote,
                    note: $captureNote,
                    onSave: {
                        commentStore.addComment(quote: selection.quote,
                                                prefix: selection.prefix,
                                                suffix: selection.suffix,
                                                note: captureNote)
                        pendingSelection = nil
                    },
                    onCancel: { pendingSelection = nil }
                )
            }
        } else {
            Text(store.isScanning ? "Scanning folder…" : "Select a file from the sidebar")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // Jump the preview to a comment's highlight and flash it; reset the trigger
    // shortly after so jumping to the same comment again re-fires.
    private func jump(to id: UUID) {
        selectedCommentID = id
        flashAnchorID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if flashAnchorID == id { flashAnchorID = nil }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Folder header
            HStack(spacing: 6) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.accent)
                Text(store.rootFolderURL?.lastPathComponent ?? "Folder")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                Spacer()
                if store.isScanning {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Text("\(store.fileCount)")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(AppColors.toolbarBackground)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(AppColors.divider), alignment: .bottom)
            .help(store.rootFolderURL?.path ?? "")

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(store.fileTree) { node in
                        FileTreeRow(node: node, depth: 0)
                    }
                }
                .padding(6)
            }
        }
        .background(AppColors.editorBackground)
    }

    // MARK: - Preview header

    private var previewHeader: some View {
        HStack(spacing: 8) {
            if !store.fileTree.isEmpty {
                headerButton(
                    icon: "sidebar.left",
                    tooltip: showSidebar ? "Hide sidebar" : "Show sidebar"
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) { showSidebar.toggle() }
                }
            }

            if let url = store.currentFileURL {
                Text(url.lastPathComponent)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .help(url.path)
            }

            Spacer()

            if showCopied {
                Text("Copied")
                    .font(.caption2)
                    .foregroundStyle(AppColors.accent)
                    .transition(.opacity)
            }

            if store.currentFileURL != nil {
                headerButton(
                    icon: showComments ? "text.bubble.fill" : "text.bubble",
                    tooltip: showComments ? "Hide comments" : "Show comments"
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) { showComments.toggle() }
                }
                headerButton(
                    icon: "quote.bubble",
                    tooltip: selectedComment == nil
                        ? "Select a comment to copy its section"
                        : "Copy this section as instruction",
                    disabled: selectedComment == nil
                ) {
                    if let comment = selectedComment {
                        copy(CommentInstructionCompiler.section(for: comment, in: store.fileContent))
                    }
                }
                headerButton(icon: "doc.on.clipboard", tooltip: "Copy whole file as instruction") {
                    copy(CommentInstructionCompiler.wholeFile(comments: commentStore.comments,
                                                              in: store.fileContent))
                }
            }

            headerButton(icon: "pencil", tooltip: "Edit in Transform tab") {
                MarkdownPreviewRouter.shared.request(store.fileContent)
            }
            headerButton(icon: "chevron.left.forwardslash.chevron.right", tooltip: "Copy as HTML") {
                copy(RichTextTransformer.markdownToHTML(store.fileContent))
            }
            headerButton(icon: "doc.richtext", tooltip: "Copy as Rich Text") {
                let attrStr = RichTextTransformer.markdownToRichText(store.fileContent)
                Pasteboard.copy(attrStr)
                flashCopied()
            }
            if let url = store.currentFileURL {
                headerButton(icon: "folder", tooltip: "Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
            headerButton(icon: "xmark.circle", tooltip: "Close") {
                store.closeAll()
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 30)
        .background(AppColors.toolbarBackground)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(AppColors.divider), alignment: .bottom)
    }

    private func headerButton(icon: String, tooltip: String, disabled: Bool = false,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(disabled ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(tooltip)
    }

    /// The currently-selected comment, if any — drives "Copy this section".
    private var selectedComment: Comment? {
        guard let id = selectedCommentID else { return nil }
        return commentStore.comments.first { $0.id == id }
    }

    // MARK: - Drop support

    @ViewBuilder
    private var dropHighlight: some View {
        if isDropTargeted {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(AppColors.accent, lineWidth: 2)
                .background(AppColors.accent.opacity(0.06))
                .padding(4)
                .allowsHitTesting(false)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                MarkdownDocumentStore.shared.open(url: url)
            }
        }
        return true
    }

    // MARK: - Clipboard

    private func copy(_ text: String) {
        Pasteboard.copy(text)
        flashCopied()
    }

    private func flashCopied() {
        withAnimation { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopied = false }
        }
    }

    // MARK: - Open dialogs (also invoked from the status bar menu)

    @discardableResult
    static func presentOpenDialog(directories: Bool) -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseFiles = !directories
        panel.canChooseDirectories = directories
        panel.allowsMultipleSelection = false
        if !directories {
            // Derive the allowed types from the store's canonical extension set
            // so the dialog never diverges from what the Reader actually opens.
            panel.allowedContentTypes = MarkdownDocumentStore.markdownExtensions
                .sorted()
                .compactMap { UTType(filenameExtension: $0) }
        }
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        return MarkdownDocumentStore.shared.open(url: url, external: true)
    }
}

/// A text selection captured from the preview, awaiting a note. Identifiable so
/// it can drive the capture popover via `.popover(item:)`.
private struct PendingSelection: Identifiable {
    let id = UUID()
    let quote: String
    let prefix: String
    let suffix: String
}

/// One row of the Reader sidebar tree — a selectable file, or a collapsible
/// folder that renders its children by direct recursion. A separate struct so
/// each folder keeps its own expansion state.
private struct FileTreeRow: View {
    let node: MarkdownFileNode
    let depth: Int

    @State private var store = MarkdownDocumentStore.shared
    @State private var isExpanded = true

    var body: some View {
        if node.isDirectory {
            folderRow
        } else {
            fileRow
        }
    }

    private var folderRow: some View {
        VStack(alignment: .leading, spacing: 1) {
            Button {
                withAnimation(.easeInOut(duration: 0.12)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(node.name)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.75))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.leading, CGFloat(depth) * 12 + 6)
                .padding(.vertical, 3.5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(node.children ?? []) { child in
                    FileTreeRow(node: child, depth: depth + 1)
                }
            }
        }
    }

    private var fileRow: some View {
        let isSelected = store.currentFileURL == node.url
        return Button {
            store.openFile(node.url)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? AppColors.accent : Color.secondary)
                Text(node.name)
                    .font(.system(size: 11.5, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? AppColors.textPrimary : Color.primary.opacity(0.85))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, CGFloat(depth) * 12 + 6)
            .padding(.trailing, 6)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? AppColors.activeTab : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(node.url.path)
    }
}

private extension String {
    /// "/Users/admin/Documents" → "~/Documents" for compact path display.
    var abbreviatingHome: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return hasPrefix(home) ? "~" + dropFirst(home.count) : self
    }
}
