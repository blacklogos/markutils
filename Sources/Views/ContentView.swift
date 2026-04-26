import SwiftUI

struct ContentView: View {
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @State private var selectedTab = 0
    @State private var isPinned = true
    @State private var socialInput = ""
    @State private var showOnboarding = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var previewRouter = MarkdownPreviewRouter.shared

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
        }
        .onChange(of: previewRouter.pendingText) { _, newValue in
            if newValue != nil { selectedTab = 1 }
        }
        // Absorb ⌘N so the system never opens a new document window.
        .background(Button("") {}.keyboardShortcut("n", modifiers: .command).hidden())
    }

    // MARK: - Compact title bar
    //
    // 72pt left inset reserves horizontal space for the native traffic-light cluster.
    // Plain icon buttons (no segmented control background) are visible in the titlebar zone.
    // WindowDragView background makes the entire row draggable.
    private var titleBar: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: 8) // left breathing room

            // Tab icons
            tabIcon(0, icon: "square.grid.2x2",        tooltip: "Assets")
            tabIcon(1, icon: "arrow.left.arrow.right",  tooltip: "Transform")
            tabIcon(2, icon: "textformat.abc",           tooltip: "Text Formatter")
            tabIcon(3, icon: "square.and.pencil",        tooltip: "Notes")

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
        case 0: AssetGridView()
        case 1: QuickActionsView()
        case 2: SocialMediaFormatterView(text: $socialInput)
        case 3: NotesView()
        default: AssetGridView()
        }
    }

    // MARK: - Button helpers

    private func tabIcon(_ tag: Int, icon: String, tooltip: String) -> some View {
        let isSelected = selectedTab == tag
        return Button { selectedTab = tag } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? AppColors.accent : Color.secondary)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
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
