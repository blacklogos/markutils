import Foundation
import Observation

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

    var currentFileURL: URL?
    var fileContent: String = ""
    var rootFolderURL: URL?
    var fileTree: [MarkdownFileNode] = []
    var loadError: String?

    /// Bumped on every external open (Finder, drag onto the app) so views can
    /// switch to the Reader tab even if the same file is opened twice.
    private(set) var externalOpenCount = 0

    /// Most recently opened files/folders, newest first. Persisted as paths.
    private(set) var recentURLs: [URL] = []

    private static let recentsKey = "readerRecentPaths"
    private static let recentsLimit = 6
    private var fileWatcher: DispatchSourceFileSystemObject?

    init() {
        recentURLs = (UserDefaults.standard.stringArray(forKey: Self.recentsKey) ?? [])
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func isMarkdownFile(_ url: URL) -> Bool {
        markdownExtensions.contains(url.pathExtension.lowercased())
    }

    // MARK: - Opening

    /// Opens a file or folder. Returns true if the URL was viewable.
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
        do {
            fileContent = try String(contentsOf: url, encoding: .utf8)
        } catch {
            // Fall back through common encodings before giving up.
            if let data = try? Data(contentsOf: url),
               let text = String(data: data, encoding: .utf16) ?? String(data: data, encoding: .isoLatin1) {
                fileContent = text
            } else {
                loadError = "Could not read \(url.lastPathComponent)."
                return false
            }
        }
        currentFileURL = url
        loadError = nil
        // Keep the folder context when selecting a file inside the open tree;
        // opening a file outside the tree switches to single-file mode.
        // Resolve symlinks so /var vs /private/var style aliases compare equal.
        if let root = rootFolderURL,
           !url.resolvingSymlinksInPath().path.hasPrefix(root.resolvingSymlinksInPath().path + "/") {
            rootFolderURL = nil
            fileTree = []
        }
        watchCurrentFile()
        return true
    }

    @discardableResult
    func openFolder(_ url: URL) -> Bool {
        let tree = Self.scanFolder(url)
        guard !tree.isEmpty else {
            loadError = "No markdown files found in \(url.lastPathComponent)."
            return false
        }
        rootFolderURL = url
        fileTree = tree
        loadError = nil
        // Auto-select the first file so the preview is never empty.
        if let first = Self.firstFile(in: tree) {
            openFile(first.url)
        }
        return true
    }

    func reloadCurrentFile() {
        guard let url = currentFileURL else { return }
        openFile(url)
    }

    func closeAll() {
        currentFileURL = nil
        fileContent = ""
        rootFolderURL = nil
        fileTree = []
        loadError = nil
        fileWatcher?.cancel()
        fileWatcher = nil
    }

    // MARK: - Folder scanning

    /// Builds a tree of markdown files under `url`. Hidden entries are skipped,
    /// directories without any markdown descendants are pruned, and siblings are
    /// sorted folders-first, then case-insensitively by name.
    static func scanFolder(_ url: URL, depth: Int = 0) -> [MarkdownFileNode] {
        // Defensive cap for pathological nesting / symlink loops.
        guard depth < 12 else { return [] }

        let contents = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        var nodes: [MarkdownFileNode] = []
        for entry in contents {
            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            if values?.isSymbolicLink == true { continue }
            if values?.isDirectory == true {
                let children = scanFolder(entry, depth: depth + 1)
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
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self, let url = self.currentFileURL else { return }
            if FileManager.default.fileExists(atPath: url.path) {
                self.fileContent = (try? String(contentsOf: url, encoding: .utf8)) ?? self.fileContent
                // Editors that save via rename replace the inode — re-arm the watcher.
                self.watchCurrentFile()
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        fileWatcher = source
    }
}
