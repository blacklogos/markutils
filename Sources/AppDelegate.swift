import SwiftUI
import UniformTypeIdentifiers
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem!
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    var floatingPanel: FloatingPanel!
    var window: NSWindow!
    var mouseShakeDetector: MouseShakeDetector!

    private var globalHotkeyMonitor: Any?
    private var notesPanelHotkeyMonitor: Any?
    var notesPanel: NotesPanel?
    private var clipboardHistoryMenuItem: NSMenuItem?

    
    func applicationDidFinishLaunching(_ notification: Notification) {
        checkSingleInstance()
        
        // Hide Dock Icon
        NSApp.setActivationPolicy(.accessory)
        
        // Setup Status Item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "Clip")
            button.action = #selector(togglePanel)
            // Right click to show menu
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Setup Menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Clip", action: #selector(togglePanel), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Open Notes  ⌥A", action: #selector(toggleNotesPanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // Theme Submenu
        let themeMenu = NSMenu()
        themeMenu.addItem(NSMenuItem(title: "System", action: #selector(setThemeSystem), keyEquivalent: ""))
        themeMenu.addItem(NSMenuItem(title: "Light", action: #selector(setThemeLight), keyEquivalent: ""))
        themeMenu.addItem(NSMenuItem(title: "Dark", action: #selector(setThemeDark), keyEquivalent: ""))

        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        menu.addItem(NSMenuItem.separator())

        // Clipboard History toggle
        let cbEnabled = ClipboardMonitor.shared.isEnabled
        let cbItem = NSMenuItem(
            title: cbEnabled ? "Clipboard History: On" : "Clipboard History: Off",
            action: #selector(toggleClipboardHistory),
            keyEquivalent: ""
        )
        cbItem.state = cbEnabled ? .on : .off
        menu.addItem(cbItem)
        clipboardHistoryMenuItem = cbItem

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Export Vault…", action: #selector(exportVault), keyEquivalent: "e"))
        menu.addItem(NSMenuItem(title: "Import Vault…", action: #selector(importVault), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        let checkForUpdatesItem = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: "u"
        )
        checkForUpdatesItem.target = updaterController
        menu.addItem(checkForUpdatesItem)
        menu.addItem(NSMenuItem(title: "Install CLI…", action: #selector(installCLIFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Keyword Reference", action: #selector(showKeywordReference), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Send Feedback", action: #selector(sendFeedback), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
        
        // Setup Floating Panel
        createFloatingPanel()
        
        // Setup Mouse Shake Detector
        mouseShakeDetector = MouseShakeDetector()
        mouseShakeDetector.onShake = { [weak self] in
            self?.showPanel()
        }
        mouseShakeDetector.startMonitoring()

        // Global hotkey: Cmd+Shift+C (keyCode 8 = C)
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.intersection([.command, .shift, .option, .control]) == [.command, .shift],
                  event.keyCode == 8 else { return }
            DispatchQueue.main.async { self?.togglePanel() }
        }

        // Global hotkey: ⌥A (keyCode 0 = A) — dedicated to Notes panel
        notesPanelHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.intersection([.command, .shift, .option, .control]) == [.option],
                  event.keyCode == 0 else { return }
            DispatchQueue.main.async { self?.toggleNotesPanel() }
        }

        // Offer CLI install on first launch
        offerCLIInstallIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = globalHotkeyMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = notesPanelHotkeyMonitor { NSEvent.removeMonitor(monitor) }
        ClipboardMonitor.shared.stopMonitoring()
    }
    
    private func createFloatingPanel() {
        let contentView = ContentView()
        
        let viewWithModel = AnyView(
            contentView
                .environment(AssetStore.shared)
                .environment(NoteStore.shared)
        )
        
        let hostingController = NSHostingController(rootView: viewWithModel)
        
        floatingPanel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 750),
            backing: .buffered,
            defer: false
        )
        
        floatingPanel.contentViewController = hostingController
        floatingPanel.center()
        floatingPanel.delegate = self // Set delegate to handle closing
        floatingPanel.isReleasedWhenClosed = false // Don't release memory when closed
    }
    
    @objc func togglePanel() {
        // Left click toggles the panel; right click shows the context menu.
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            statusItem.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        } else {
            if floatingPanel.isVisible {
                floatingPanel.orderOut(nil)
            } else {
                floatingPanel.makeKeyAndOrderFront(nil)
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
    }
    
    @objc func toggleClipboardHistory() {
        ClipboardMonitor.shared.isEnabled.toggle()
        let enabled = ClipboardMonitor.shared.isEnabled
        clipboardHistoryMenuItem?.title = enabled ? "Clipboard History: On" : "Clipboard History: Off"
        clipboardHistoryMenuItem?.state = enabled ? .on : .off
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc func setThemeSystem() { UserDefaults.standard.set("System", forKey: "appTheme") }
    @objc func setThemeLight() { UserDefaults.standard.set("Light", forKey: "appTheme") }
    @objc func setThemeDark() { UserDefaults.standard.set("Dark", forKey: "appTheme") }
    
    @objc func sendFeedback() {
        if let url = URL(string: "https://github.com/blacklogos/markutils/issues") {
            NSWorkspace.shared.open(url)
        }
    }

    private var keywordReferencePanel: NSPanel?

    @objc func showKeywordReference() {
        if keywordReferencePanel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 480),
                styleMask: [.titled, .closable, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.title = "Keyword Reference"
            panel.level = .floating
            panel.isReleasedWhenClosed = false
            panel.contentViewController = NSHostingController(rootView: KeywordReferenceView())
            panel.center()
            keywordReferencePanel = panel
        }
        keywordReferencePanel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // NSWindowDelegate - Handle window closing (red x button)
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide instead of closing
        sender.orderOut(nil)
        return false // Return false to prevent actual closing
    }
    
    func showPanel() {
        if !floatingPanel.isVisible {
            floatingPanel.makeKeyAndOrderFront(nil)
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func createNotesPanel() {
        let rootView = AnyView(
            NotesView()
                .environment(NoteStore.shared)
                .environment(AssetStore.shared)
        )
        notesPanel = NotesPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 640),
            backing: .buffered,
            defer: false
        )
        notesPanel?.contentViewController = NSHostingController(rootView: rootView)
        notesPanel?.center()
        notesPanel?.delegate = self
        notesPanel?.isReleasedWhenClosed = false
    }

    @objc func toggleNotesPanel() {
        if notesPanel == nil { createNotesPanel() }
        guard let panel = notesPanel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
    
    // MARK: - Export / Import

    @objc func exportVault() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "clip-backup-\(formattedDate()).json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(AssetStore.shared.assets)
            try data.write(to: url)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.runModal()
        }
    }

    @objc func importVault() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        // Confirm replacement
        let confirm = NSAlert()
        confirm.messageText = "Replace Vault?"
        confirm.informativeText = "This will replace all current assets with the imported data. This cannot be undone."
        confirm.alertStyle = .warning
        confirm.addButton(withTitle: "Replace")
        confirm.addButton(withTitle: "Cancel")

        guard confirm.runModal() == .alertFirstButtonReturn else { return }

        do {
            let data = try Data(contentsOf: url)
            let assets = try JSONDecoder().decode([Asset].self, from: data)
            AssetStore.shared.assets = assets
        } catch {
            let alert = NSAlert()
            alert.messageText = "Import Failed"
            alert.informativeText = "Invalid backup file: \(error.localizedDescription)"
            alert.alertStyle = .critical
            alert.runModal()
        }
    }

    private func formattedDate() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd"
        return fmt.string(from: Date())
    }

    // MARK: - CLI Install

    private func offerCLIInstallIfNeeded() {
        let cliInstalled = UserDefaults.standard.bool(forKey: "cliInstallOffered")
        let cliExists = FileManager.default.fileExists(atPath: "/usr/local/bin/clip")

        // Don't prompt if already installed or already offered
        guard !cliInstalled && !cliExists else { return }

        // Check if the bundled CLI binary exists
        guard let bundledCLI = Bundle.main.path(forResource: "clip", ofType: nil) else { return }

        UserDefaults.standard.set(true, forKey: "cliInstallOffered")

        let alert = NSAlert()
        alert.messageText = "Install clip CLI?"
        alert.informativeText = "Install the clip command-line tool to /usr/local/bin for terminal access.\n\nYou can also install it later from the menu bar."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Not Now")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        installCLI(from: bundledCLI)
    }

    @objc func installCLIFromMenu() {
        guard let bundledCLI = Bundle.main.path(forResource: "clip", ofType: nil) else {
            let alert = NSAlert()
            alert.messageText = "CLI binary not found"
            alert.informativeText = "The clip binary is missing from the app bundle."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        installCLI(from: bundledCLI)
    }

    private func installCLI(from sourcePath: String) {
        let dest = "/usr/local/bin/clip"
        let script = "mkdir -p /usr/local/bin && cp '\(sourcePath)' '\(dest)' && chmod +x '\(dest)' && xattr -rd com.apple.quarantine '\(dest)'"

        let appleScript = NSAppleScript(source: "do shell script \"\(script)\" with administrator privileges")
        var error: NSDictionary?
        appleScript?.executeAndReturnError(&error)

        if let error = error {
            let alert = NSAlert()
            alert.messageText = "Installation failed"
            alert.informativeText = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            alert.alertStyle = .warning
            alert.runModal()
        } else {
            let alert = NSAlert()
            alert.messageText = "CLI installed"
            alert.informativeText = "The clip command is now available in your terminal.\n\nTry: clip --help"
            alert.alertStyle = .informational
            alert.runModal()
        }
    }

    private func checkSingleInstance() {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        
        if runningApps.count > 1 {
            // Found another instance
            // Activate the other instance(s)
            for app in runningApps where app != NSRunningApplication.current {
                app.activate(options: [.activateIgnoringOtherApps])
            }
            
            // Terminate this instance
            NSApp.terminate(nil)
        }
    }
}
