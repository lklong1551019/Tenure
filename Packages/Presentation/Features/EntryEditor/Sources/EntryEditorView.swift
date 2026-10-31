import DesignSystem
import Domain
import SwiftUI

/// The task sheet: basics, the story in five parts, and the numbers.
public struct EntryEditorView: View {
    @Bindable private var model: EntryEditorViewModel

    public init(model: EntryEditorViewModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(model.isNew ? "New task" : "Edit task")
                        .appFont(17, weight: .semibold)
                    basics
                    story
                    metrics
                }
                .padding(24)
            }
            Divider()
            footer
        }
        .frame(width: 640, height: 720)
        .background(Palette.ground)
    }

    // MARK: Sections

    private var basics: some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledField("Name") {
                TextField("Cut cold start in half", text: $model.name)
                    .fieldChrome()
            }
            HStack(alignment: .top, spacing: 12) {
                LabeledField("Board") {
                    Picker("Board", selection: $model.boardId) {
                        ForEach(model.boards) { board in
                            Text(board.name).tag(board.id)
                        }
                    }
                    .labelsHidden()
                }
                LabeledField("Kind") {
                    Picker("Kind", selection: $model.type) {
                        ForEach(model.types, id: \.self) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
            }
            HStack(alignment: .bottom, spacing: 12) {
                LabeledField("Date") {
                    DatePicker("Date", selection: $model.date, displayedComponents: .date)
                        .labelsHidden()
                }
                Toggle("Spans several days", isOn: $model.hasEndDate)
                if model.hasEndDate {
                    LabeledField("Until") {
                        DatePicker("Until", selection: $model.endDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
            }
            LabeledField("Link") {
                TextField("https://jira.example.com/browse/APP-1421", text: $model.link)
                    .fieldChrome()
            }
            LabeledField("Tags") {
                TextField("performance, android, ci", text: $model.tags)
                    .fieldChrome()
            }
        }
        .cardSurface()
    }

    private var story: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The story")
                .appFont(13, weight: .semibold)
            // verbatim: a plain literal would render the Markdown and hide the syntax it teaches.
            Text(
                verbatim:
                    "Markdown works: **bold**, *italic*, `code`, [link](https://...). Select text and press Cmd-B, Cmd-I, Cmd-E, or Cmd-L."
            )
            .appFont(11)
            .foregroundStyle(Palette.mutedInk)
            textArea("Problem", "What was wrong, and who felt it?", text: $model.problem)
            textArea("Why", "Why it mattered enough to work on.", text: $model.why)
            textArea("Solution", "What you built or changed, and how.", text: $model.solution)
            textArea("Impact", "What changed for users, the team, or the business.", text: $model.impact)
            textArea(
                "Difficulties and how you solved them",
                "What got in the way, and how you got past it.",
                text: $model.difficulties
            )
        }
        .cardSurface()
    }

    private var metrics: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Metrics")
                    .appFont(13, weight: .semibold)
                Spacer()
                Button("Add metric", systemImage: "plus") { model.addMetric() }
                    .buttonStyle(.borderless)
            }
            if model.metrics.isEmpty {
                Text("Numbers that prove the impact: before and after, and how they were measured.")
                    .appFont(12)
                    .foregroundStyle(Palette.secondaryInk)
            }
            ForEach($model.metrics) { $metric in
                MetricRow(metric: $metric) { model.removeMetric(metric.id) }
            }
        }
        .cardSurface()
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if let message = model.errorMessage {
                ErrorLine(message)
            } else if let problem = model.problemText, !model.name.isEmpty {
                ErrorLine(problem)
            }
            Spacer()
            Button("Cancel") { model.cancel() }
                .buttonStyle(SecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)
            Button(model.isNew ? "Add task" : "Save") { Task { await model.save() } }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!model.canSave)
                .help("Save (Cmd-Return)")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private func textArea(_ label: String, _ hint: String, text: Binding<String>) -> some View {
        StoryField(label: label, hint: hint, text: text)
    }
}

/// One story part: a multi-line field with format buttons (Cmd-B, Cmd-I, Cmd-E, Cmd-L) that
/// wrap the selection in Markdown. The buttons and their shortcuts work only while this field
/// has focus, so the shortcuts never reach the other fields.
private struct StoryField: View {
    let label: String
    let hint: String
    @Binding var text: String
    @State private var selection: TextSelection?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                Text(label)
                    .appFont(12, weight: .semibold)
                    .foregroundStyle(Palette.secondaryInk)
                Spacer()
                ForEach(MarkdownFormat.allCases, id: \.self) { format in
                    Button {
                        apply(format)
                    } label: {
                        Image(systemName: format.symbol)
                            .frame(width: 22, height: 18)
                    }
                    .buttonStyle(.borderless)
                    .keyboardShortcut(KeyEquivalent(format.key), modifiers: .command)
                    .help("\(format.title) (Cmd-\(String(format.key).uppercased()))")
                    .accessibilityLabel(format.title)
                }
                .opacity(isFocused ? 1 : 0)
                .disabled(!isFocused)
                .accessibilityHidden(!isFocused)
            }
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(hint)
                        .appFont(13)
                        .foregroundStyle(Palette.mutedInk)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text, selection: $selection)
                    .appFont(13)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .focused($isFocused)
            }
            .frame(minHeight: 64)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.controlRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.controlRadius)
                    .strokeBorder(isFocused ? Palette.accent : Palette.borderStrong)
            )
        }
    }

    private func apply(_ format: MarkdownFormat) {
        let range: Range<String.Index> =
            switch selection?.indices {
            case .selection(let range): range
            default: text.endIndex..<text.endIndex
            }
        let lower = text.distance(from: text.startIndex, to: range.lowerBound)
        let upper = text.distance(from: text.startIndex, to: range.upperBound)
        let result = format.apply(to: text, selection: lower..<upper)
        text = result.text
        let start = text.index(text.startIndex, offsetBy: result.selection.lowerBound)
        let end = text.index(text.startIndex, offsetBy: result.selection.upperBound)
        selection = TextSelection(range: start..<end)
    }
}

private struct MetricRow: View {
    @Binding var metric: MetricDraft
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                TextField("Cold start p50", text: $metric.label)
                    .fieldChrome()
                TextField("Before", text: $metric.before)
                    .fieldChrome()
                    .frame(width: 90)
                Image(systemName: "arrow.right")
                    .foregroundStyle(Palette.mutedInk)
                    .accessibilityHidden(true)
                TextField("After", text: $metric.after)
                    .fieldChrome()
                    .frame(width: 90)
                TextField("Unit", text: $metric.unit)
                    .fieldChrome()
                    .frame(width: 60)
                Button(action: onRemove) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .help("Remove metric")
                .accessibilityLabel("Remove metric")
            }
            TextField("How it was measured: device, runs, time window", text: $metric.note)
                .fieldChrome()
        }
    }
}
