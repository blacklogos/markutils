import Foundation
import Observation

/// Routes markdown content from the Asset vault to the Transform tab for preview.
/// Set `pendingText` from any view, then the TransformerView consumes it on appear.
@Observable
final class MarkdownPreviewRouter {
    static let shared = MarkdownPreviewRouter()
    var pendingText: String? = nil

    func request(_ text: String) {
        pendingText = text
    }

    func consume() -> String? {
        defer { pendingText = nil }
        return pendingText
    }
}
