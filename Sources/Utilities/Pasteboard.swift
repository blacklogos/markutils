import AppKit

/// Single place all views write to the system pasteboard, so copy behavior
/// (clearing, types written) can never diverge between tabs.
enum Pasteboard {
    static func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    static func copy(_ attributedString: NSAttributedString) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([attributedString])
    }
}
