import SwiftUI
import AppKit

class FloatingPanel: NSPanel {
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.nonactivatingPanel, .titled, .resizable, .closable, .fullSizeContentView], backing: backing, defer: flag)

        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = false
        self.isReleasedWhenClosed = false
        self.standardWindowButton(.closeButton)?.isHidden = false
        self.standardWindowButton(.miniaturizeButton)?.isHidden = false
        self.standardWindowButton(.zoomButton)?.isHidden = false
        self.minSize = NSSize(width: 450, height: 400)
        self.setFrameAutosaveName("ClipFloatingPanel")

        // Match the transparent titlebar zone to the toolbar background so there
        // is no visible seam between the titlebar area and the custom header below.
        self.backgroundColor = NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(srgbRed: 42/255,  green: 42/255,  blue: 42/255,  alpha: 1) // #2A2A2A
                : NSColor(srgbRed: 240/255, green: 237/255, blue: 232/255, alpha: 1) // #F0EDE8
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
