import Foundation

/// A single reader comment: a free-text note anchored to a quoted span of the
/// source markdown. Lives in `ClipCore` (not the app target) because the pure
/// anchoring and instruction-compiling functions operate on it, and `ClipCore`
/// must not depend on the app target.
///
/// Anchoring is by quoted text + surrounding context, never line/offset — the
/// renderer has no AST or source map, so `quote`/`prefix`/`suffix` re-locate the
/// span on reload and degrade gracefully (re-find, or flag `needsReview`).
public struct Comment: Codable, Identifiable, Equatable {
    public enum Status: String, Codable, Equatable {
        case active
        case needsReview
    }

    public let id: UUID
    /// The exact selected text the comment is anchored to.
    public var quote: String
    /// Short text immediately before `quote` in the source, for disambiguation.
    public var prefix: String
    /// Short text immediately after `quote` in the source, for disambiguation.
    public var suffix: String
    /// The Creator's free-text note.
    public var note: String
    public var createdAt: Date
    public var status: Status

    public init(
        id: UUID = UUID(),
        quote: String,
        prefix: String = "",
        suffix: String = "",
        note: String,
        createdAt: Date = Date(),
        status: Status = .active
    ) {
        self.id = id
        self.quote = quote
        self.prefix = prefix
        self.suffix = suffix
        self.note = note
        self.createdAt = createdAt
        self.status = status
    }
}
