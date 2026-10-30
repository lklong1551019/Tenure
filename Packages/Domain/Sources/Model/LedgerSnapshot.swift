import Foundation

/// Everything the app stores, live items and tombstones alike. The same value is written to
/// the local file and uploaded to Drive.
public struct LedgerSnapshot: Sendable, Hashable, Codable {
    public static let empty = LedgerSnapshot()

    public var boards: [Board]
    public var entries: [Entry]

    public init(boards: [Board] = [], entries: [Entry] = []) {
        self.boards = boards
        self.entries = entries
    }

    public var liveBoards: [Board] {
        boards.filter { !$0.isDeleted }.sorted(by: Board.timelineOrder)
    }

    public var liveEntries: [Entry] {
        let boardIds = Set(boards.filter { !$0.isDeleted }.map(\.id))
        return entries.filter { !$0.isDeleted && boardIds.contains($0.boardId) }
    }
}
