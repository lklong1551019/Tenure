import AppKit
import DesignSystem
import SwiftUI

struct AboutView: View {
    static let repository = URL(string: "https://github.com/lklong1551019/Tenure")!
    static let privacyPolicy = URL(string: "https://lklong1551019.github.io/Tenure/privacy.html")!

    let info: AboutInfo
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tenure")
                        .appFont(17, weight: .semibold)
                    Text("Version \(info.version) (\(info.code))")
                        .appFont(13)
                        .foregroundStyle(Palette.secondaryInk)
                        .textSelection(.enabled)
                    if info.isDevelopmentBuild {
                        Badge("Development build", tint: .amber)
                    }
                }
                Spacer()
            }
            Text(
                "A record of what you did in your career: boards per company, the story of each task, and the numbers that prove it."
            )
            .appFont(13)
            .foregroundStyle(Palette.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 16) {
                Button("Check for Updates...") { openWindow(id: UpdateView.windowID) }
                Link("Source code", destination: Self.repository)
                Link("Privacy policy", destination: Self.privacyPolicy)
            }
            .appFont(13)
        }
        .padding(24)
        .frame(width: 480, alignment: .leading)
    }
}
