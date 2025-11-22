import SwiftUI

struct WindowDragView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = MouseDragView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

class MouseDragView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
}
