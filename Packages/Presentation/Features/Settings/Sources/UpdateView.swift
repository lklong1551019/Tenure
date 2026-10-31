import AppKit
import DesignSystem
import Domain
import SwiftUI

/// The Software Update window: whether a newer version exists, what changed in each version
/// since this one, and how to install it. Tenure is built on each Mac, so installing is a
/// pull and `scripts/install-app.sh`, not a download.
public struct UpdateView: View {
    public static let windowID = "updates"

    @Bindable private var model: UpdateViewModel
    @Environment(\.dismissWindow) private var dismissWindow

    public init(model: UpdateViewModel) {
        self.model = model
    }

    public var body: some View {
        // Sized by its content (the window uses .contentSize): compact when there is nothing
        // to list, taller with release notes.
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(24)
            Divider()
            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
            Divider()
            footer
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
        }
        .frame(width: 600)
        .fixedSize(horizontal: false, vertical: true)
        .background(Palette.surface)
        .task {
            if model.state == .idle { await model.check() }
        }
        .onAppear { model.markAnnounced() }
        .onChange(of: model.latest) { model.markAnnounced() }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(headline)
                    .appFont(17, weight: .semibold)
                    .foregroundStyle(Palette.ink)
                Text(subheadline)
                    .appFont(13)
                    .foregroundStyle(Palette.secondaryInk)
            }
            Spacer()
            if model.state == .checking {
                ProgressView().controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .available(let releases):
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    installHint
                    ForEach(releases) { release in
                        ReleaseNotesView(release: release)
                    }
                }
                .padding(24)
            }
            .frame(height: 360)
        case .failed(let message):
            ErrorLine(message)
                .padding(24)
        case .upToDate:
            message("You have the newest version. Release notes for every version are on the web.")
        case .idle, .checking:
            message("Looking at the published releases on GitHub...")
        }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .appFont(13)
            .foregroundStyle(Palette.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
            .padding(24)
    }

    private var installHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("To update, pull the latest code and install it on this Mac:")
                .appFont(13)
                .foregroundStyle(Palette.secondaryInk)
            HStack {
                Text(UpdateViewModel.installCommand)
                    .appFont(12, design: .monospaced)
                    .textSelection(.enabled)
                Spacer()
                Button("Copy") { model.copyInstallCommand() }
                    .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Palette.sunken, in: RoundedRectangle(cornerRadius: Metrics.controlRadius))
        }
    }

    /// The switch on its own line, the buttons below it at their natural width, so large text
    /// sizes never wrap a button label.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Check for updates every 12 hours", isOn: $model.checksAutomatically)
                .toggleStyle(.checkbox)
                .appFont(13)
            HStack(spacing: 10) {
                Spacer()
                Button("Release notes") { model.openReleasePage() }
                    .buttonStyle(SecondaryButtonStyle())
                    .fixedSize()
                Button("Check again") { Task { await model.check() } }
                    .buttonStyle(SecondaryButtonStyle())
                    .fixedSize()
                    .disabled(model.state == .checking)
                Button("Close") { dismissWindow(id: Self.windowID) }
                    .buttonStyle(PrimaryButtonStyle())
                    .fixedSize()
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var headline: String {
        switch model.state {
        case .idle, .checking: "Checking for updates..."
        case .upToDate: "Tenure is up to date"
        case .available(let releases): "Tenure \(releases.first?.version ?? "") is available"
        case .failed: "Couldn't check for updates"
        }
    }

    private var subheadline: String {
        switch model.state {
        case .available(let releases):
            let count = releases.count == 1 ? "" : " (\(releases.count) releases)"
            return "You have \(model.currentVersion)\(count)."
        default:
            return "This Mac runs version \(model.currentVersion)."
        }
    }
}

/// One release: its version and date, then what is new, fixed, and improved.
private struct ReleaseNotesView: View {
    let release: Release

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(release.version)
                    .appFont(15, weight: .bold)
                    .foregroundStyle(Palette.ink)
                Text(release.date)
                    .appFont(12)
                    .foregroundStyle(Palette.mutedInk)
            }
            section("New", release.new, tint: .blue)
            section("Fixed", release.fixed, tint: .red)
            section("Improved", release.improved, tint: .violet)
            if release.new.isEmpty && release.fixed.isEmpty && release.improved.isEmpty {
                Text("Maintenance and internal changes.")
                    .appFont(13)
                    .foregroundStyle(Palette.secondaryInk)
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [String], tint: Tint) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Badge(title, tint: tint)
                ForEach(items, id: \.self) { item in
                    Label {
                        Text(item)
                            .appFont(13)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Circle()
                            .fill(Palette.mutedInk)
                            .frame(width: 4, height: 4)
                    }
                }
            }
        }
    }
}
