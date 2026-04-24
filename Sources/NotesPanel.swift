import SwiftUI

// Borderless floating panel for the minimal Notes experience.
// No titlebar — content fills the entire window rect.
// Draggable via isMovableByWindowBackground.
class NotesPanel: NSPanel {
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect,
                   styleMask: [.nonactivatingPanel, .resizable],
                   backing: backing,
                   defer: flag)

        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.isReleasedWhenClosed = false
        self.backgroundColor = .windowBackgroundColor
        self.minSize = NSSize(width: 300, height: 360)
        self.setFrameAutosaveName("ClipNotesPanel")
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
