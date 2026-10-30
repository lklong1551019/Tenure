import DesignSystem
import Domain
import SwiftUI

/// Sheet for a board's name and time range. Edits its own copy of the draft: a binding into
/// the model's optional draft would trap when Save clears it while the sheet still draws.
struct BoardEditorView: View {
    @State private var draft: BoardDraft
    private let onSave: (BoardDraft) -> Void
    private let onCancel: () -> Void

    init(draft: BoardDraft, onSave: @escaping (BoardDraft) -> Void, onCancel: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(draft.isNew ? "New board" : "Edit board")
                .appFont(17, weight: .semibold)
            LabeledField("Name") {
                TextField("Company A", text: $draft.name)
                    .fieldChrome()
            }
            LabeledField("Started") {
                MonthPicker(value: $draft.start)
            }
            Toggle("I still work here", isOn: $draft.isCurrent)
            if !draft.isCurrent {
                LabeledField("Ended") {
                    MonthPicker(value: $draft.end)
                }
            }
            if let problem = draft.problem, !draft.name.isEmpty {
                ErrorLine(problem)
            }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button(draft.isNew ? "Add board" : "Save") { onSave(draft) }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(draft.problem != nil)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}

/// Month and year, as two menus.
struct MonthPicker: View {
    @Binding var value: YearMonth

    private static let months = Calendar.current.monthSymbols
    private static var years: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((1980...(current + 1)).reversed())
    }

    var body: some View {
        HStack(spacing: 8) {
            Picker("Month", selection: monthBinding) {
                ForEach(1...12, id: \.self) { month in
                    Text(Self.months[month - 1]).tag(month)
                }
            }
            .labelsHidden()
            Picker("Year", selection: yearBinding) {
                ForEach(Self.years, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .labelsHidden()
            .frame(width: 96)
        }
    }

    private var monthBinding: Binding<Int> {
        Binding(get: { value.month }, set: { value = YearMonth(year: value.year, month: $0) })
    }

    private var yearBinding: Binding<Int> {
        Binding(get: { value.year }, set: { value = YearMonth(year: $0, month: value.month) })
    }
}
