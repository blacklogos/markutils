import SwiftUI
import UniformTypeIdentifiers
import AppKit
import ClipCore

// Reader tab: view markdown files and folders rendered with the app's
// preview styling. Files arrive via the open buttons, drag-and-drop,
// Finder "Open With Clip", or the recents list.
struct MarkdownReaderView: View {
    @State private var store = MarkdownDocumentStore.shared
    @State private var showSidebar = true
    @State private var showCopied = false
    @State private var isDropTargeted = false

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

                HStack(spacing: 10) {
                    Button("Open File…") { Self.presentOpenDialog(directories: false) }
                        .keyboardShortcut("o", modifiers: .command)
                    Button("Open Folder…") { Self.presentOpenDialog(directories: true) }
                        .keyboardShortcut("o", modifiers: [.command, .shift])
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
                if store.currentFileURL != nil {
                    HTMLPreviewView(htmlContent: store.renderedHTML)
                } else {
                    Text(store.isScanning ? "Scanning folder…" : "Select a file from the sidebar")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
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
                        fileTreeRow(node, depth: 0)
                    }
                }
                .padding(6)
            }
        }
        .background(AppColors.editorBackground)
    }

    @ViewBuilder
    private func fileTreeRow(_ node: MarkdownFileNode, depth: Int) -> some View {
        if node.isDirectory {
            FileTreeFolderRow(node: node, depth: depth) { child, childDepth in
                AnyView(fileTreeRow(child, depth: childDepth))
            }
        } else {
            fileRow(node, depth: depth)
        }
    }

    private func fileRow(_ node: MarkdownFileNode, depth: Int) -> some View {
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

            headerButton(icon: "pencil", tooltip: "Edit in Transform tab") {
                MarkdownPreviewRouter.shared.request(store.fileContent)
            }
            headerButton(icon: "chevron.left.forwardslash.chevron.right", tooltip: "Copy as HTML") {
                copy(RichTextTransformer.markdownToHTML(store.fileContent))
            }
            headerButton(icon: "doc.richtext", tooltip: "Copy as Rich Text") {
                let attrStr = RichTextTransformer.markdownToRichText(store.fileContent)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([attrStr])
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
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
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

/// Collapsible folder row used by the Reader sidebar tree.
/// Separate struct so each folder keeps its own expansion state.
private struct FileTreeFolderRow: View {
    let node: MarkdownFileNode
    let depth: Int
    let childRow: (MarkdownFileNode, Int) -> AnyView

    @State private var isExpanded = true

    var body: some View {
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
                    childRow(child, depth + 1)
                }
            }
        }
    }
}

private extension String {
    /// "/Users/admin/Documents" → "~/Documents" for compact path display.
    var abbreviatingHome: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return hasPrefix(home) ? "~" + dropFirst(home.count) : self
    }
}
