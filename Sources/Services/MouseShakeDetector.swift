import Cocoa

class MouseShakeDetector {
    // Configuration
    private let shakeThreshold: Int = 4 // Number of reversals to consider a shake
    private let shakeWindow: TimeInterval = 0.5 // Time window to count reversals
    private let speedThreshold: CGFloat = 20.0 // Minimum distance moved to consider meaningful
    
    // State
    private var reversals: Int = 0
    private var lastDirection: CGFloat = 0 // 1 for right, -1 for left
    private var lastShakeTime: Date = Date()
    private var monitor: Any?
    
    // Callback
    var onShake: (() -> Void)?
    
    init() {}
    
    func startMonitoring() {
        // We only care about global mouse moves for this feature
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved(event)
        }
    }
    
    func stopMonitoring() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
    
    private func handleMouseMoved(_ event: NSEvent) {
        let dx = event.deltaX
        
        // Ignore small movements
        if abs(dx) < speedThreshold {
            return
        }
        
        // Check for direction reversal (shake)
        // If dx is positive (right) and last was negative (left), or vice versa
        let currentDirection: CGFloat = dx > 0 ? 1 : -1
        
        let now = Date()
        if now.timeIntervalSince(lastShakeTime) > shakeWindow {
            // Reset if too much time passed since last activity
            reversals = 0
        }
        
        if lastDirection != 0 && currentDirection != lastDirection {
            reversals += 1
            lastShakeTime = now
            
            if reversals >= shakeThreshold {
                // Shake detected!
                onShake?()
                reversals = 0 // Reset after trigger to avoid double firing immediately
            }
        } else {
            // Update timestamp even if direction is same, to keep the window open if they are just moving fast in one direction? 
            // Actually, we only care about reversals. But if they move L L L R L L L, that's reversals.
            // If they swipe L.................. then R, that's not a shake.
            // So resetting on time timeout is correct.
        }
        
        lastDirection = currentDirection
    }
    
    deinit {
        stopMonitoring()
    }
}
