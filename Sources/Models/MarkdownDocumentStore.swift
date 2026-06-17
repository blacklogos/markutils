import Foundation
import Observation
import ClipCore

/// A node in the file tree shown in the Reader sidebar.
/// Directories carry `children`; markdown files have `children == nil`.
struct MarkdownFileNode: Identifiable, Hashable {
    let url: URL
    var children: [MarkdownFileNode]?

    var id: URL { url }
    var name: String { url.lastPathComponent }
    var isDirectory: Bool { children != nil }
}

/// State for the Reader tab: a single open markdown file, or a folder whose
/// markdown files are browsable in a sidebar tree. Singleton so the
/// AppDelegate can route Finder "Open With" events into the UI.
@Observable
final class MarkdownDocumentStore {
    static let shared = MarkdownDocumentStore()

    /// File extensions treated as viewable markdown documents.
    static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkdn", "mkd", "txt"]

    /// Largest file the Reader will render — markdown beyond this would hang
    /// the main thread in the parser.
    static let maxFileBytes = 8 * 1024 * 1024

    /// Directory-entry budget for folder scans, keeping a stray "open ~/"
    /// from walking the whole disk.
    static let scanEntryBudget = 25_000

    var currentFileURL: URL?
    private(set) var fileContent: String = ""
    /// Rendered once per content change — views read this instead of
    /// re-parsing on every body evaluation.
    private(set) var renderedHTML: String = ""
    var rootFolderURL: URL?
    var fileTree: [MarkdownFileNode] = []
    private(set) var fileCount = 0
    var isScanning = false
    var loadError: String?

    /// Bumped on every external open (Finder, drag onto the app) so views can
    /// switch to the Reader tab even if the same file is opened twice.
    private(set) var externalOpenCount = 0

    /// Most recently opened files/folders, newest first. Persisted as paths.
    private(set) var recentURLs: [URL] = []

    private static let recentsKey = "readerRecentPaths"
    private static let recentsLimit = 6
    private var fileWatcher: DispatchSourceFileSystemObject?
    private var pendingReload: DispatchWorkItem?

    /// Sidecar comment store for the open document. Injectable so tests can point
    /// it at a temp directory instead of Application Support.
    let commentStore: CommentStore

    init(commentStore: CommentStore = .shared) {
        self.commentStore = commentStore
        // Load recents without touching the filesystem (paths on unmounted
        // volumes can block on automount); prune dead entries off-main.
        let candidates = (UserDefaults.standard.stringArray(forKey: Self.recentsKey) ?? [])
            .map { URL(fileURLWithPath: $0) }
        recentURLs = candidates
        guard !candidates.isEmpty else { return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let alive = candidates.filter { FileManager.default.fileExists(atPath: $0.path) }
            if alive.count != candidates.count {
                DispatchQueue.main.async { self?.recentURLs = alive }
            }
        }
    }

    static func isMarkdownFile(_ url: URL) -> Bool {
        markdownExtensions.contains(url.pathExtension.lowercased())
    }

    // MARK: - Opening

    /// Opens a file or folder. Returns true if the URL was accepted
    /// (folder scans complete asynchronously after returning).
    @discardableResult
    func open(url: URL, external: Bool = false) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            loadError = "File not found: \(url.path)"
            return false
        }

        let opened: Bool
        if isDirectory.boolValue {
            opened = openFolder(url)
        } else {
            opened = openFile(url)
        }

        if opened {
            addRecent(url)
            if external { externalOpenCount += 1 }
        }
        return opened
    }

    @discardableResult
    func openFile(_ url: URL) -> Bool {
        guard Self.isMarkdownFile(url) else {
            loadError = "\(url.lastPathComponent) isn't a markdown file. Clip can view: " +
                Self.markdownExtensions.sorted().map { ".\($0)" }.joined(separator: ", ")
            return false
        }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= Self.maxFileBytes else {
            loadError = "\(url.lastPathComponent) is too large to preview (\(size / 1_048_576) MB)."
            return false
        }
        guard let text = Self.readText(url) else {
            loadError = "Could not read \(url.lastPathComponent)."
            return false
        }
        // Load this file's comments BEFORE setContent so the re-anchor pass runs
        // against the right sidecar (covers both initial open and live reload —
        // openFile is the single funnel for both).
        commentStore.load(for: url)
        setContent(text)
        currentFileURL = url
        loadError = nil
        // Keep the folder context when selecting a file inside the open tree;
        // opening a file outside the tree switches to single-file mode.
        // Resolve symlinks so /var vs /private/var style aliases compare equal.
        if let root = rootFolderURL,
           !url.resolvingSymlinksInPath().path.hasPrefix(root.resolvingSymlinksInPath().path + "/") {
            rootFolderURL = nil
            fileTree = []
            fileCount = 0
        }
        watchCurrentFile()
        return true
    }

    /// Single read path (UTF-8 with UTF-16/Latin-1 fallback) shared by opening,
    /// live reload, and the Transform tab's file import.
    static func readText(_ url: URL) -> String? {
        if let text = try? String(contentsOf: url, encoding: .utf8) { return text }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf16) ?? String(data: data, encoding: .isoLatin1)
    }

    private func setContent(_ text: String) {
        fileContent = text
        renderedHTML = RichTextTransformer.markdownToHTML(text)
        reanchorComments(in: text)
    }

    /// Re-anchors the open file's comments against new content: found quotes stay
    /// `active`, vanished ones flip to `needsReview` — never deleted (R12, R13).
    /// Only writes back when a status actually changed, to avoid needless saves.
    private func reanchorComments(in text: String) {
        guard commentStore.currentFileURL != nil, !commentStore.comments.isEmpty else { return }
        let updated = commentStore.comments.map { CommentAnchor.reanchor($0, in: text) }
        if updated != commentStore.comments {
            commentStore.replaceAll(updated)
        }
    }

    /// Accepts the folder immediately and scans it off the main thread —
    /// large trees must not beachball the panel. `synchronous: true` is for
    /// tests and small known trees.
    @discardableResult
    func openFolder(_ url: URL, synchronous: Bool = false) -> Bool {
        if synchronous {
            applyScanResult(Self.scanFolder(url), for: url)
            return !fileTree.isEmpty
        }

        isScanning = true
        rootFolderURL = url
        fileTree = []
        fileCount = 0
        loadError = nil
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let tree = Self.scanFolder(url)
            DispatchQueue.main.async {
                guard let self, self.rootFolderURL == url else { return }
                self.isScanning = false
                self.applyScanResult(tree, for: url)
            }
        }
        return true
    }

    private func applyScanResult(_ tree: [MarkdownFileNode], for url: URL) {
        guard !tree.isEmpty else {
            loadError = "No markdown files found in \(url.lastPathComponent)."
            if rootFolderURL == url { rootFolderURL = nil }
            fileTree = []
            fileCount = 0
            return
        }
        rootFolderURL = url
        fileTree = tree
        fileCount = Self.fileCount(in: tree)
        loadError = nil
        // Auto-select the first file so the preview is never empty,
        // unless the user already opened a file from this tree.
        let rootPath = url.resolvingSymlinksInPath().path + "/"
        let currentInsideTree = currentFileURL.map {
            $0.resolvingSymlinksInPath().path.hasPrefix(rootPath)
        } ?? false
        if !currentInsideTree, let first = Self.firstFile(in: tree) {
            openFile(first.url)
        }
    }

    func closeAll() {
        currentFileURL = nil
        fileContent = ""
        renderedHTML = ""
        rootFolderURL = nil
        fileTree = []
        fileCount = 0
        isScanning = false
        loadError = nil
        pendingReload?.cancel()
        pendingReload = nil
        fileWatcher?.cancel()
        fileWatcher = nil
    }

    // MARK: - Folder scanning

    /// Builds a tree of markdown files under `url`. Hidden entries are skipped,
    /// directories without any markdown descendants are pruned, and siblings are
    /// sorted folders-first, then case-insensitively by name. The walk stops
    /// descending once `scanEntryBudget` entries have been visited.
    static func scanFolder(_ url: URL) -> [MarkdownFileNode] {
        var budget = scanEntryBudget
        return scanFolder(url, depth: 0, budget: &budget)
    }

    private static func scanFolder(_ url: URL, depth: Int, budget: inout Int) -> [MarkdownFileNode] {
        // Defensive caps for pathological nesting / symlink loops / huge trees.
        guard depth < 12, budget > 0 else { return [] }

        let contents = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var nodes: [MarkdownFileNode] = []
        for entry in contents {
            guard budget > 0 else { break }
            budget -= 1
            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if values?.isSymbolicLink == true { continue }
            if values?.isDirectory == true {
                let children = scanFolder(entry, depth: depth + 1, budget: &budget)
                if !children.isEmpty {
                    nodes.append(MarkdownFileNode(url: entry, children: children))
                }
            } else if isMarkdownFile(entry) {
                nodes.append(MarkdownFileNode(url: entry, children: nil))
            }
        }

        return nodes.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    static func firstFile(in nodes: [MarkdownFileNode]) -> MarkdownFileNode? {
        for node in nodes {
            if !node.isDirectory { return node }
            if let found = firstFile(in: node.children ?? []) { return found }
        }
        return nil
    }

    static func fileCount(in nodes: [MarkdownFileNode]) -> Int {
        nodes.reduce(0) { count, node in
            count + (node.isDirectory ? fileCount(in: node.children ?? []) : 1)
        }
    }

    // MARK: - Recents

    private func addRecent(_ url: URL) {
        recentURLs.removeAll { $0 == url }
        recentURLs.insert(url, at: 0)
        if recentURLs.count > Self.recentsLimit {
            recentURLs = Array(recentURLs.prefix(Self.recentsLimit))
        }
        UserDefaults.standard.set(recentURLs.map(\.path), forKey: Self.recentsKey)
    }

    // MARK: - Live reload

    /// Watches the open file and reloads the preview when it changes on disk,
    /// so editing in another app updates Clip without manual refresh.
    private func watchCurrentFile() {
        fileWatcher?.cancel()
        fileWatcher = nil
        guard let url = currentFileURL else { return }

        let fd = Foundation.open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.scheduleReload()
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        fileWatcher = source
    }

    /// Debounced reload: editors fire several events per save (and atomic
    /// saves briefly delete the path), so wait for the dust to settle, then
    /// go through the normal openFile path — which re-reads with encoding
    /// fallbacks and re-arms the watcher on the new inode.
    private func scheduleReload(retriesLeft: Int = 3) {
        pendingReload?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let url = self.currentFileURL else { return }
            if FileManager.default.fileExists(atPath: url.path) {
                self.openFile(url)
            } else if retriesLeft > 0 {
                // Atomic save: file is momentarily gone — try again shortly.
                self.scheduleReload(retriesLeft: retriesLeft - 1)
            }
            // After the retries: file genuinely deleted. Keep showing the last
            // content; the next watcher arm happens if the user reopens.
        }
        pendingReload = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }
}
