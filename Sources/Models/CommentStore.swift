import Foundation
import Observation
import CryptoKit
import ClipCore

/// Per-document comment persistence. Mirrors `AssetStore`: an `@Observable`
/// singleton that eager-saves on mutation. Comments for the currently-open file
/// live as JSON at `~/Library/Application Support/Clip/comments/<key>.json`,
/// where `<key>` is a stable hash of the file's resolved path.
///
/// The source `.md` is NEVER opened for writing here — comments are a sidecar,
/// so the document's own bytes are untouched (R11). Tradeoff: moving/renaming
/// the `.md` outside Clip detaches its comments (rename-tracking is deferred).
@Observable
final class CommentStore {
    static let shared = CommentStore(
        directory: FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Clip/comments")
    )

    /// Comments for the currently-loaded file. Eager-saves on every mutation,
    /// except while `load(for:)` is populating from disk.
    private(set) var comments: [Comment] = [] {
        didSet { if !isLoading { save() } }
    }

    /// The file whose comments are currently held. `save()` targets its sidecar.
    private(set) var currentFileURL: URL?

    private let directory: URL
    private var isLoading = false

    // Default date strategy (.deferredToDate) so `createdAt` round-trips to the
    // exact same `Date` — iso8601 would drop sub-second precision and break
    // value equality across a save/load cycle.
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    private static let decoder = JSONDecoder()

    init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Stable, filesystem-safe key for a file: SHA-256 of its symlink-resolved
    /// path. Deterministic across launches (Swift's `Hasher` is not).
    static func key(for url: URL) -> String {
        let path = url.resolvingSymlinksInPath().path
        let digest = SHA256.hash(data: Data(path.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func sidecarURL(for url: URL) -> URL {
        directory.appendingPathComponent(Self.key(for: url) + ".json")
    }

    /// Loads the sidecar for `url` into `comments`. A file with no sidecar yields
    /// an empty list and no error. Does not write back during load.
    func load(for url: URL) {
        currentFileURL = url
        isLoading = true
        defer { isLoading = false }

        let target = sidecarURL(for: url)
        guard FileManager.default.fileExists(atPath: target.path),
              let data = try? Data(contentsOf: target),
              let loaded = try? Self.decoder.decode([Comment].self, from: data)
        else {
            comments = []
            return
        }
        comments = loaded
    }

    func add(_ comment: Comment) {
        comments.append(comment)
    }

    func delete(_ comment: Comment) {
        comments.removeAll { $0.id == comment.id }
    }

    /// Replaces a comment in place (note edit, status change) by id. No-op if absent.
    func update(_ comment: Comment) {
        guard let idx = comments.firstIndex(where: { $0.id == comment.id }) else { return }
        comments[idx] = comment
    }

    /// Replaces the whole set at once — used by re-anchoring on reload so a single
    /// save covers the batch.
    func replaceAll(_ new: [Comment]) {
        comments = new
    }

    func save() {
        guard let url = currentFileURL else { return }
        do {
            let data = try Self.encoder.encode(comments)
            try data.write(to: sidecarURL(for: url))
        } catch {
            // Silent — avoid exposing file paths in console logs (matches NoteStore).
        }
    }
}
