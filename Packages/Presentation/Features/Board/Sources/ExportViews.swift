import DesignSystem
import Domain
import SwiftUI
import UniformTypeIdentifiers

/// Sheet for exporting one year: which year, which boards, and what to include. Edits its own
/// copy of the draft, as `BoardEditorView` does.
struct YearExportView: View {
    @State private var draft: YearExportDraft
    let years: [Int]
    let boards: [Board]
    let summary: (YearExportDraft) -> String
    let onExport: (YearExportDraft) -> Void
    let onCancel: () -> Void

    init(
        draft: YearExportDraft,
        years: [Int],
        boards: [Board],
        summary: @escaping (YearExportDraft) -> String,
        onExport: @escaping (YearExportDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.years = years
        self.boards = boards
        self.summary = summary
        self.onExport = onExport
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Export a year")
                .appFont(17, weight: .semibold)
            LabeledField("Year") {
                Picker("Year", selection: $draft.year) {
                    ForEach(years, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .labelsHidden()
            }
            LabeledField("Boards") {
                Picker("Boards", selection: $draft.boardId) {
                    Text("All boards").tag(UUID?.none)
                    ForEach(boards) { board in
                        Text("\(board.name) only").tag(UUID?.some(board.id))
                    }
                }
                .labelsHidden()
            }
            LabeledField("Include") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("The story: problem, why, solution, impact, difficulties", isOn: $draft.options.story)
                    Toggle("Metrics table", isOn: $draft.options.metrics)
                    Toggle("Links and tags", isOn: $draft.options.linksAndTags)
                }
                .toggleStyle(.checkbox)
            }
            Text(summary(draft))
                .appFont(13)
                .foregroundStyle(Palette.secondaryInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Palette.sunken, in: RoundedRectangle(cornerRadius: Metrics.controlRadius))
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("Export...") { onExport(draft) }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

/// The text handed to the save panel.
struct MarkdownDocument: FileDocument {
    static let markdown = UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText
    static let readableContentTypes = [markdown]

    let text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        text = configuration.file.regularFileContents.map { String(decoding: $0, as: UTF8.self) } ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
