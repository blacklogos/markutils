import SwiftUI

/// The five tools, in titlebar order. Single source of truth for icons,
/// tooltips, ⌘-number shortcuts, and routing targets — add a case here and
/// every tab surface updates together.
enum AppTab: Int, CaseIterable {
    case assets, reader, transform, format, notes

    var icon: String {
        switch self {
        case .assets:    return "square.grid.2x2"
        case .reader:    return "book.pages"
        case .transform: return "arrow.left.arrow.right"
        case .format:    return "textformat.abc"
        case .notes:     return "square.and.pencil"
        }
    }

    var title: String {
        switch self {
        case .assets:    return "Assets"
        case .reader:    return "Reader"
        case .transform: return "Transform"
        case .format:    return "Text Formatter"
        case .notes:     return "Notes"
        }
    }

    var shortcut: KeyEquivalent { KeyEquivalent(Character("\(rawValue + 1)")) }
    var tooltip: String { "\(title) ⌘\(rawValue + 1)" }
}

struct ContentView: View {
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @State private var selectedTab: AppTab = .assets
    @State private var isPinned = true
    @State private var socialInput = ""
    @State private var showOnboarding = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var previewRouter = MarkdownPreviewRouter.shared
    @State private var documentStore = MarkdownDocumentStore.shared

    enum AppTheme: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"

        var id: String { rawValue }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light:  return .light
            case .dark:   return .dark
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider()
            tabContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.windowBackground)
        .preferredColorScheme(appTheme.colorScheme)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .onAppear {
            if !hasSeenOnboarding { showOnboarding = true }
            // App was launched by opening a document — land on the Reader tab.
            if documentStore.externalOpenCount > 0 { selectedTab = .reader }
        }
        .onChange(of: previewRouter.pendingText) { _, newValue in
            if newValue != nil { selectedTab = .transform }
        }
        // Finder "Open With Clip" (or drag onto the app) routes to the Reader tab.
        .onChange(of: documentStore.externalOpenCount) { _, _ in
            selectedTab = .reader
        }
        // Absorb ⌘N so the system never opens a new document window.
        .background(Button("") {}.keyboardShortcut("n", modifiers: .command).hidden())
        // ⌘1–⌘5 switch tabs directly.
        .background(tabShortcuts)
    }

    // MARK: - Compact title bar
    //
    // 72pt left inset reserves horizontal space for the native traffic-light cluster.
    // Plain icon buttons (no segmented control background) are visible in the titlebar zone.
    // WindowDragView background makes the entire row draggable.
    private var titleBar: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 8) // left breathing room

            ForEach(AppTab.allCases, id: \.self) { tab in
                tabIcon(tab)
            }

            Spacer() // draggable gap

            // Utility icons
            toolbarButton(icon: themeIcon, tint: nil, tooltip: "Theme: \(appTheme.rawValue)", action: cycleTheme)
            toolbarButton(
                icon: isPinned ? "pin.fill" : "pin",
                tint: isPinned ? AppColors.accent : nil,
                tooltip: isPinned ? "Unpin from top" : "Pin to top",
                action: togglePin
            )

            Color.clear.frame(width: 8) // right breathing room
        }
        .frame(height: 30)
        .background(AppColors.toolbarBackground)
        .background(WindowDragView())
    }

    // MARK: - Tab content area

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .assets:    AssetGridView()
        case .reader:    MarkdownReaderView()
        case .transform: QuickActionsView()
        case .format:    SocialMediaFormatterView(text: $socialInput)
        case .notes:     NotesView()
        }
    }

    private var tabShortcuts: some View {
        ForEach(AppTab.allCases, id: \.self) { tab in
            Button("") { selectedTab = tab }
                .keyboardShortcut(tab.shortcut, modifiers: .command)
                .hidden()
        }
    }

    // MARK: - Button helpers

    private func tabIcon(_ tab: AppTab) -> some View {
        let isSelected = selectedTab == tab
        return Button { selectedTab = tab } label: {
            Image(systemName: tab.icon)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? AppColors.accent : Color.secondary)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tab.tooltip)
    }

    private func toolbarButton(icon: String, tint: Color?, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(tint ?? Color.secondary)
                .frame(width: 28, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    // MARK: - Actions

    private func togglePin() {
        isPinned.toggle()
        if let window = NSApp.keyWindow {
            window.level = isPinned ? .floating : .normal
        }
    }

    private func cycleTheme() {
        switch appTheme {
        case .system: appTheme = .light
        case .light:  appTheme = .dark
        case .dark:   appTheme = .system
        }
    }

    private var themeIcon: String {
        switch appTheme {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }
}
