# Research: NSPanel Multi-Window & File Export (macOS Swift 5.9)

## Topic 1: Second NSPanel Floating Window in SwiftUI/AppKit Hybrid

### NSHostingView Pattern
- `NSHostingView` directly embeds SwiftUI view hierarchies into AppKit view hierarchies without requiring a view controller.
- Initialize: `NSHostingView(rootView: SwiftUI.View)`
- Attach to `NSPanel.contentView` or use as subview in AppKit container.
- Manages sizing, layout constraints, and view state automatically.

### Multiple Panels Coexistence
- macOS 14+ supports multiple windows via SwiftUI `WindowGroup` with unique identifiers.
- For AppKit approach: create separate `NSPanel` instances with distinct window levels (`.floating`, `.normal`).
- Main FloatingPanel: `.floating` level keeps it above other windows.
- NotesPanel: can be `.floating` or `.normal` depending on desired behavior.
- Both panels managed independently in `AppDelegate`; no built-in synchronization—must wire manually.

### Showing/Hiding Secondary Panel from AppDelegate
- Maintain `NotesPanel` as `@State` property in `AppDelegate`.
- Create toggle method: `func toggleNotesPanel() { notesPanel?.orderFront(nil) }` or `notesPanel?.orderOut(nil)`.
- Optionally store reference in singleton/shared container for access from other contexts.
- Use `NSApp.delegate as? AppDelegate` to access from menu actions or button handlers.

### Keeping Secondary Panel in Sync with @Observable Store
- Share `@Observable` `AssetStore` instance between main panel's `NSHostingView` and NotesPanel's `NSHostingView`.
- Pass same `AssetStore` instance to both view roots: `NSHostingView(rootView: ContentView(store: sharedStore))`.
- AppKit doesn't natively observe `@Observable`; rely on SwiftUI's reactivity within each `NSHostingView`.
- For cross-panel updates: have NotesPanel listen to `AssetStore` changes via property observers or pass reactive state down.
- Caveat: `NSPanel.contentView` updates must be triggered by SwiftUI's state changes; direct AppKit mutations won't auto-sync.

---

## Topic 2: File Export from macOS SwiftUI App

### SwiftUI fileExporter (Preferred Path)
- Use `fileExporter` modifier (iOS 17+, macOS 14+) for sheet-style export.
- Syntax: `.fileExporter(isPresented: $isExporting, items: [textContent], contentTypes: [.plainText], onCompletion: { result in })`.
- Automatically presents file save dialog with filename input field.
- Handles .md and .txt via `UTType.plainText` or `.markdown`.
- Custom button label: `.fileDialogConfirmationLabel("Save")`.
- Custom filename field label: `.fileExporterFilenameLabel("Notes")`.
- No sandbox restrictions for SwiftUI fileExporter on macOS.

### NSSavePanel (Lower-Level Alternative)
- Direct AppKit approach: `NSSavePanel().runModal()` or `.begin()` for async.
- Set properties: `allowedContentTypes`, `canCreateDirectories`, `allowsOtherFileTypes`.
- Returns `.OK` or `.cancel`; access saved path via `.url` property.
- Blocking (modal) vs async (begin) choice depends on app flow.
- Less discoverable in hybrid SwiftUI context; fileExporter is recommended.

### NSPasteboard (Clipboard Copy)
- For text to clipboard: `NSPasteboard.general.setString(content, forType: .string)`.
- Alternative: `NSPasteboard.general.setData(content.data(using: .utf8), forType: .rtf)` for rich text.
- No user interaction required; synchronous copy.
- No sandbox implications for read/write to general pasteboard.
- Quick for "Copy to Clipboard" buttons in NotesPanel.

### Sandbox Considerations
- SwiftUI's `fileExporter` is sandbox-aware on macOS; system handles file write permission.
- No entitlements needed for standard file save dialogs.
- NSPasteboard access is unrestricted in standard macOS apps.
- If using `NSSavePanel` with hardcoded paths (e.g., Downloads), request appropriate sandbox capability.
- Recommendation: stick with `fileExporter` for safest, most modern approach.

---

## Practical Implementation Notes

**Pattern for NotesPanel:**
1. Create `NotesPanel` as subclass of `NSPanel` with `.floating` level (or `.normal` if not always-on-top).
2. Initialize `NSHostingView(rootView: NotesPanelView(store: sharedAssetStore))` as contentView.
3. Toggle visibility from AppDelegate: `notesPanel.isVisible ? notesPanel.orderOut(nil) : notesPanel.orderFront(nil)`.
4. Store reference in `AppDelegate` for lifecycle management.

**Pattern for Export Flow:**
1. Add `@State var isExportingNotes = false` in NotesPanel view.
2. Button action sets `isExportingNotes = true`.
3. Chain `.fileExporter()` modifier with `.fileDialogConfirmationLabel("Save Note")`.
4. `onCompletion` handler writes content or confirms success.

**Unresolved Questions:**
- How to sync `@Observable` mutations between NotesPanel and main panel if NotesPanel updates the store independently? (Likely automatic via shared reference, but edge cases possible.)
- Does NSPanel with NSHostingView properly release SwiftUI resources on close, or do we need explicit cleanup?
