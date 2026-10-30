import Domain
import Foundation
import Observation

@MainActor
public protocol EntryEditorActions: AnyObject {
    /// Live boards, newest first.
    var boards: [Board] { get }
    func saveEntry(_ entry: Entry) async throws
    func closeEditor()
    func now() -> Timestamp
}

/// One editable metric row. Empty strings stand for "not set".
public struct MetricDraft: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var label: String
    public var before: String
    public var after: String
    public var unit: String
    public var note: String

    public init(_ metric: Metric? = nil) {
        id = metric?.id ?? UUID()
        label = metric?.label ?? ""
        before = metric?.before ?? ""
        after = metric?.after ?? ""
        unit = metric?.unit ?? ""
        note = metric?.note ?? ""
    }

    /// Blank rows are dropped on save.
    var isBlank: Bool {
        [label, before, after, unit, note].allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var metric: Metric {
        Metric(
            id: id,
            label: label.trimmed,
            before: before.trimmed.nilIfEmpty,
            after: after.trimmed,
            unit: unit.trimmed.nilIfEmpty,
            note: note.trimmed.nilIfEmpty
        )
    }
}

/// The task sheet. Edits a copy; nothing is saved until Save.
@MainActor
@Observable
public final class EntryEditorViewModel: Identifiable {
    public nonisolated let id = UUID()
    public let isNew: Bool
    public var boardId: UUID
    public var name: String
    public var link: String
    public var type: EntryType
    public var date: Date
    public var hasEndDate: Bool
    public var endDate: Date
    /// Comma-separated, as typed.
    public var tags: String
    public var problem: String
    public var why: String
    public var solution: String
    public var impact: String
    public var difficulties: String
    public var metrics: [MetricDraft]
    public private(set) var isSaving = false
    public private(set) var errorMessage: String?

    private let original: Entry?
    private let actions: any EntryEditorActions

    /// `entry` nil starts a new task on `boardId`, or on the newest board.
    public init(entry: Entry?, boardId: UUID?, actions: any EntryEditorActions) {
        self.actions = actions
        original = entry
        isNew = entry == nil
        let today = actions.now().date
        self.boardId = entry?.boardId ?? boardId ?? actions.boards.first?.id ?? UUID()
        name = entry?.name ?? ""
        link = entry?.link ?? ""
        type = entry?.type ?? .dev
        date = entry?.date.date() ?? today
        hasEndDate = entry?.endDate != nil
        endDate = entry?.endDate?.date() ?? entry?.date.date() ?? today
        tags = entry?.tags.joined(separator: ", ") ?? ""
        problem = entry?.problem ?? ""
        why = entry?.why ?? ""
        solution = entry?.solution ?? ""
        impact = entry?.impact ?? ""
        difficulties = entry?.difficulties ?? ""
        metrics = entry?.metrics.map(MetricDraft.init) ?? []
    }

    public var boards: [Board] { actions.boards }

    /// Kinds offered in the picker, including an unknown one the task already has.
    public var types: [EntryType] {
        EntryType.known.contains(type) ? EntryType.known : EntryType.known + [type]
    }

    /// Nil when the task can be saved.
    public var problemText: String? {
        if name.trimmed.isEmpty { return "Enter a name." }
        if !boards.contains(where: { $0.id == boardId }) { return "Choose a board." }
        if hasEndDate && DayDate(endDate) < DayDate(date) { return "The end date comes before the start." }
        if metrics.contains(where: { !$0.isBlank && ($0.label.trimmed.isEmpty || $0.after.trimmed.isEmpty) }) {
            return "Each metric needs a label and a value."
        }
        return nil
    }

    public var canSave: Bool { problemText == nil && !isSaving }

    public func addMetric() {
        metrics.append(MetricDraft())
    }

    public func removeMetric(_ id: UUID) {
        metrics.removeAll { $0.id == id }
    }

    public func moveMetrics(from source: IndexSet, to destination: Int) {
        metrics.move(fromOffsets: source, toOffset: destination)
    }

    /// The task as it would be saved; `updatedAt` is stamped by the store.
    public var entry: Entry {
        Entry(
            id: original?.id ?? id,
            boardId: boardId,
            name: name.trimmed,
            link: link.trimmed.nilIfEmpty,
            type: type,
            date: DayDate(date),
            endDate: hasEndDate ? DayDate(endDate) : nil,
            tags: Self.parseTags(tags),
            problem: problem.trimmed,
            why: why.trimmed,
            solution: solution.trimmed,
            impact: impact.trimmed,
            difficulties: difficulties.trimmed,
            metrics: metrics.filter { !$0.isBlank }.map(\.metric),
            createdAt: original?.createdAt ?? actions.now()
        )
    }

    public func save() async {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await actions.saveEntry(entry)
            actions.closeEditor()
        } catch {
            errorMessage = "Couldn't save the task. Try again."
        }
    }

    public func cancel() {
        actions.closeEditor()
    }

    /// "ios, perf ,  ci,ios" becomes ["ios", "perf", "ci"].
    nonisolated static func parseTags(_ text: String) -> [String] {
        var seen = Set<String>()
        return text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "#")) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
}

extension String {
    fileprivate var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    fileprivate var nilIfEmpty: String? { isEmpty ? nil : self }
}
