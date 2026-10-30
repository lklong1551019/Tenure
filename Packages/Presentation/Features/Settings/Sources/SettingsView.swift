import DesignSystem
import Domain
import SwiftUI
import UniformTypeIdentifiers

/// The Settings window (Cmd+,): General and About tabs.
public struct SettingsView: View {
    @Bindable private var model: SettingsViewModel
    @Binding private var theme: AppTheme
    private let about: AboutInfo
    @State private var confirmsSignOut = false
    @State private var exportDocument: JSONFile?
    @State private var isImporting = false

    public init(model: SettingsViewModel, theme: Binding<AppTheme>, about: AboutInfo) {
        self.model = model
        _theme = theme
        self.about = about
    }

    public var body: some View {
        TabView {
            general
                .tabItem { Label("General", systemImage: "gearshape") }
            AboutView(info: about)
                .tabItem { Label("About", systemImage: "info.circle") }
        }
    }

    private var general: some View {
        Form {
            appearanceSection
            syncSection
            dataSection
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .task {
            await model.load()
            await model.observe()
        }
        .fileExporter(
            isPresented: Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }),
            document: exportDocument,
            contentType: .json,
            defaultFilename: "tenure.json"
        ) { result in
            model.exported(result)
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            Task { await model.importFile(result) }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $theme) {
                ForEach(AppTheme.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            Text("System follows the macOS appearance setting.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.secondaryInk)
        }
    }

    private var syncSection: some View {
        Section("Google Drive") {
            if !model.isConfigured {
                Text("Google Drive sync isn't set up in this build. See docs/GOOGLE-SETUP.md.")
                    .foregroundStyle(Palette.secondaryInk)
            } else if !model.isSignedIn {
                Button(model.isWorking ? "Signing in..." : "Sign in with Google") {
                    Task { await model.signIn() }
                }
                .disabled(model.isWorking)
                Text(
                    "Keeps a copy of your data in a \"Tenure\" folder in your Google Drive. Tenure can see only the files it creates."
                )
                .font(.system(size: 12))
                .foregroundStyle(Palette.secondaryInk)
                if let error = model.signInError {
                    ErrorLine(error)
                }
            } else {
                LabeledContent("Status") {
                    Label(
                        model.statusText(),
                        systemImage: model.hasProblem ? "exclamationmark.triangle" : "checkmark.icloud"
                    )
                    .foregroundStyle(model.hasProblem ? Palette.danger : Palette.secondaryInk)
                }
                HStack {
                    Button("Sync now") { Task { await model.syncNow() } }
                        .disabled(!model.canSyncNow)
                    Spacer()
                    Button("Sign out...", role: .destructive) { confirmsSignOut = true }
                }
            }
        }
        .confirmationDialog("Sign out of Google Drive?", isPresented: $confirmsSignOut) {
            Button("Sign out", role: .destructive) { Task { await model.signOut() } }
        } message: {
            Text("Sync stops on this Mac. The data here and the copy in Google Drive both stay.")
        }
    }

    private var dataSection: some View {
        Section("Data") {
            LabeledContent("Data file") {
                Button("Show in Finder") { model.revealDataFile() }
            }
            HStack {
                Button("Export...") {
                    Task {
                        if let data = await model.exportData() {
                            exportDocument = JSONFile(data: data)
                        }
                    }
                }
                Button("Import...") { isImporting = true }
                Spacer()
            }
            Text("Import merges a tenure.json into your data: newer edits win, nothing is lost.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.secondaryInk)
            if let message = model.dataMessage {
                if model.dataMessageIsError {
                    ErrorLine(message)
                } else {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.success)
                }
            }
        }
    }
}

/// `tenure.json` bytes for the save panel.
struct JSONFile: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
