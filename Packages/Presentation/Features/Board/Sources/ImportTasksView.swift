import DesignSystem
import Domain
import SwiftUI
import UniformTypeIdentifiers

/// Sheet for adding many tasks at once: paste rows from a spreadsheet (or open a CSV or TSV
/// file), pick the board and kind, check the preview, import. Edits its own copy of the draft,
/// as `BoardEditorView` does.
struct ImportTasksView: View {
    @State private var draft: ImportDraft
    @State private var isChoosingFile = false
    @State private var fileError: String?
    let boards: [Board]
    let kinds: [EntryType]
    let review: (ImportDraft) -> [ImportRow]
    let onImport: (ImportDraft) -> Void
    let onCancel: () -> Void

    init(
        draft: ImportDraft,
        boards: [Board],
        kinds: [EntryType],
        review: @escaping (ImportDraft) -> [ImportRow],
        onImport: @escaping (ImportDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.boards = boards
        self.kinds = kinds
        self.review = review
        self.onImport = onImport
        self.onCancel = onCancel
    }

    var body: some View {
        let rows = review(draft)
        let ready = rows.count { $0.isReady }
        VStack(alignment: .leading, spacing: 16) {
            Text("Import tasks")
                .appFont(17, weight: .semibold)
            Text(
                "Paste rows copied from Excel or Numbers, or open a CSV or TSV file. Columns: name, link, date, end date (optional). Dates like 2025-03-12 or 12/03/2025, day first. A second column that is not a link becomes the problem."
            )
            .appFont(12)
            .foregroundStyle(Palette.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .bottom, spacing: 12) {
                LabeledField("Board") {
                    Picker("Board", selection: $draft.boardId) {
                        ForEach(boards) { board in
                            Text(board.name).tag(board.id)
                        }
                    }
                    .labelsHidden()
                }
                LabeledField("Kind") {
                    Picker("Kind", selection: $draft.type) {
                        ForEach(kinds, id: \.self) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .labelsHidden()
                }
                Spacer()
                Button("Open file...") { isChoosingFile = true }
                    .buttonStyle(SecondaryButtonStyle())
                    .fixedSize()
            }
            pasteArea
            if let fileError {
                ErrorLine(fileError)
            }
            preview(rows)
            HStack {
                Text(summary(rows))
                    .appFont(12)
                    .foregroundStyle(Palette.secondaryInk)
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button(ready == 0 ? "Import" : "Import \(ready.counted("task"))") { onImport(draft) }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(ready == 0)
            }
        }
        .padding(24)
        .frame(width: 760)
        .fileImporter(
            isPresented: $isChoosingFile,
            allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText]
        ) { result in
            load(result)
        }
    }

    private var pasteArea: some View {
        ZStack(alignment: .topLeading) {
            if draft.text.isEmpty {
                Text("Fix crash on cold start\thttps://jira.example.com/browse/APP-12\t2025-03-12")
                    .appFont(12, design: .monospaced)
                    .foregroundStyle(Palette.mutedInk)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $draft.text)
                .appFont(12, design: .monospaced)
                .scrollContentBackground(.hidden)
                .padding(4)
        }
        .frame(height: 120)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.controlRadius))
        .overlay(RoundedRectangle(cornerRadius: Metrics.controlRadius).strokeBorder(Palette.borderStrong))
    }

    private func preview(_ rows: [ImportRow]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(rows) { row in
                    ImportRowView(row: row)
                    Divider()
                }
            }
        }
        .frame(height: 260)
        .background(Palette.sunken, in: RoundedRectangle(cornerRadius: Metrics.controlRadius))
        .overlay {
            if rows.isEmpty {
                Text("The rows you paste show here before anything is added.")
                    .appFont(13)
                    .foregroundStyle(Palette.mutedInk)
            }
        }
    }

    /// "82 ready · 3 need a date · 1 already on the board".
    private func summary(_ rows: [ImportRow]) -> String {
        guard !rows.isEmpty else { return "" }
        var parts = ["\(rows.count { $0.isReady }) ready"]
        let missingDate = rows.count { $0.status == .missingDate }
        if missingDate > 0 { parts.append("\(missingDate) need a date") }
        let duplicate = rows.count { $0.status == .duplicate }
        if duplicate > 0 { parts.append("\(duplicate) already on the board") }
        let other = rows.count - rows.count { $0.isReady } - missingDate - duplicate
        if other > 0 { parts.append("\(other) to fix") }
        return parts.joined(separator: " · ")
    }

    private func load(_ result: Result<URL, any Error>) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if let text = try? String(contentsOf: url, encoding: .utf8) ?? String(contentsOf: url, encoding: .utf16) {
            draft.text = text
            fileError = nil
        } else {
            fileError = "Couldn't read that file as text."
        }
    }
}

/// One previewed row: whether it will be added, and what it holds.
private struct ImportRowView: View {
    let row: ImportRow

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(row.line)")
                .appFont(11)
                .monospacedDigit()
                .foregroundStyle(Palette.mutedInk)
                .frame(width: 26, alignment: .trailing)
            Image(systemName: row.isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(row.isReady ? Palette.success : Palette.warning)
                .accessibilityLabel(row.isReady ? "Ready" : "Not imported")
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name.isEmpty ? "No name" : row.name)
                    .appFont(13, weight: .medium)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                if let detail {
                    Text(detail)
                        .appFont(11)
                        .foregroundStyle(Palette.mutedInk)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 8)
            Text(trailing)
                .appFont(12)
                .foregroundStyle(row.isReady ? Palette.secondaryInk : Palette.warning)
                .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var detail: String? {
        row.link ?? row.note
    }

    private var trailing: String {
        switch row.status {
        case .ready:
            guard let date = row.date else { return "" }
            guard let end = row.endDate, end != date else { return date.short }
            return "\(date.short) - \(end.short)"
        case .missingName: return "Needs a name"
        case .missingDate: return "Needs a date"
        case .unreadableDate(let text): return "Can't read \"\(text)\""
        case .endBeforeStart: return "Ends before it starts"
        case .duplicate: return "Already on the board"
        }
    }
}
