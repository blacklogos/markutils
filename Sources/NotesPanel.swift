import SwiftUI

// Standalone floating panel dedicated to the Notes feature.
// Mirrors FloatingPanel.swift exactly — different autosave name, min size, and default rect.
class NotesPanel: NSPanel {
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect,
                   styleMask: [.nonactivatingPanel, .titled, .resizable, .closable, .fullSizeContentView],
                   backing: backing,
                   defer: flag)

        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = false
        self.isReleasedWhenClosed = false
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        self.minSize = NSSize(width: 350, height: 400)
        self.setFrameAutosaveName("ClipNotesPanel")
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
