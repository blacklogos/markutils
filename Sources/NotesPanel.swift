import SwiftUI

// Borderless floating panel for the minimal Notes experience.
// isOpaque=false + backgroundColor=.clear lets SwiftUI render rounded corners
// by making areas outside the RoundedRectangle fully transparent.
class NotesPanel: NSPanel {
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect,
                   styleMask: [.nonactivatingPanel, .resizable, .miniaturizable],
                   backing: backing,
                   defer: flag)

        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.isReleasedWhenClosed = false
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.minSize = NSSize(width: 300, height: 360)
        self.setFrameAutosaveName("ClipNotesPanel")
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
