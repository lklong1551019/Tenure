import Domain
import Foundation
import Testing

@testable import EntryEditorFeature

@MainActor
final class FakeEditorActions: EntryEditorActions {
    let boards: [Board]
    var saved: [Entry] = []
    var closed = false

    init(boards: [Board]) {
        self.boards = boards
    }

    func saveEntry(_ entry: Entry) async throws {
        saved.append(entry)
    }

    func closeEditor() {
        closed = true
    }

    func now() -> Timestamp { Timestamp(millis: 1_790_000_000_000) }
}

@MainActor
@Suite("EntryEditorViewModel")
struct EntryEditorViewModelTests {
    let board = Board(name: "A", start: YearMonth(year: 2019, month: 9), createdAt: Timestamp(millis: 0))

    @Test func newEntryNeedsAName() async {
        let actions = FakeEditorActions(boards: [board])
        let model = EntryEditorViewModel(entry: nil, boardId: nil, actions: actions)
        #expect(model.boardId == board.id)
        #expect(model.problemText == "Enter a name.")
        await model.save()
        #expect(actions.saved.isEmpty)
    }

    @Test func saveTrimsAndDropsBlankMetrics() async throws {
        let actions = FakeEditorActions(boards: [board])
        let model = EntryEditorViewModel(entry: nil, boardId: board.id, actions: actions)
        model.name = "  Cold start  "
        model.link = "   "
        model.tags = "perf, #android ,perf, "
        model.addMetric()
        model.addMetric()
        model.metrics[0].label = "p50"
        model.metrics[0].before = "1.8s"
        model.metrics[0].after = "0.9s"
        await model.save()
        let entry = try #require(actions.saved.first)
        #expect(entry.name == "Cold start")
        #expect(entry.link == nil)
        #expect(entry.tags == ["perf", "android"])
        #expect(entry.metrics.map(\.after) == ["0.9s"])
        #expect(actions.closed)
    }

    @Test func incompleteMetricBlocksSave() {
        let model = EntryEditorViewModel(entry: nil, boardId: board.id, actions: FakeEditorActions(boards: [board]))
        model.name = "X"
        model.addMetric()
        model.metrics[0].label = "p50"
        #expect(model.problemText == "Each metric needs a label and a value.")
    }

    @Test func editingKeepsIdentityAndUnknownKind() {
        let original = Entry(
            boardId: board.id,
            name: "Old",
            type: EntryType(rawValue: "research"),
            date: DayDate(year: 2024, month: 1, day: 2),
            createdAt: Timestamp(millis: 5)
        )
        let model = EntryEditorViewModel(entry: original, boardId: nil, actions: FakeEditorActions(boards: [board]))
        #expect(model.types.last == EntryType(rawValue: "research"))
        model.name = "New"
        let entry = model.entry
        #expect(entry.id == original.id)
        #expect(entry.createdAt == Timestamp(millis: 5))
        #expect(entry.date == DayDate(year: 2024, month: 1, day: 2))
    }
}
