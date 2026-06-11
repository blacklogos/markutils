import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    private struct Feature {
        let icon: String
        let title: String
        let detail: String
    }

    private let features: [Feature] = [
        Feature(icon: "square.grid.2x2",
                title: "Assets",
                detail: "Drag in images and snippets you reuse — organized in folders."),
        Feature(icon: "book.pages",
                title: "Reader",
                detail: "Open markdown files or whole folders, beautifully rendered."),
        Feature(icon: "arrow.left.arrow.right",
                title: "Transform",
                detail: "Markdown ↔ HTML ↔ rich text, tables ↔ CSV — paste and convert."),
        Feature(icon: "textformat.abc",
                title: "Format",
                detail: "Unicode styles for social posts: bold, italic, and more."),
        Feature(icon: "square.and.pencil",
                title: "Notes",
                detail: "A daily scratchpad, one keystroke away (⌥A)."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 10) {
                Image(systemName: "paperclip.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(AppColors.accent)

                Text("Welcome to Clip")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)

                Text("The markdown toolbox in your menu bar.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 36)
            .padding(.bottom, 26)

            // Feature list
            VStack(alignment: .leading, spacing: 14) {
                ForEach(features, id: \.title) { feature in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppColors.accent)
                            .frame(width: 24, alignment: .center)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(feature.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AppColors.textPrimary)
                            Text(feature.detail)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.horizontal, 44)

            Spacer()

            // Action button
            Button {
                hasSeenOnboarding = true
                isPresented = false
            } label: {
                Text("Start Using Clip")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: 220)
                    .padding(.vertical, 10)
                    .background(AppColors.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
            .padding(.bottom, 8)

            Text("Tip: shake your mouse or press ⌘⇧C to summon Clip anywhere.")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 22)
        }
        .frame(width: 420, height: 520)
        .background(AppColors.windowBackground)
    }
}
