import Foundation

/// What a Markdown export includes besides each task's name, kind, and date.
public struct MarkdownOptions: Sendable, Hashable {
    /// Problem, why, solution, impact, difficulties.
    public var story: Bool
    public var metrics: Bool
    public var linksAndTags: Bool

    public init(story: Bool = true, metrics: Bool = true, linksAndTags: Bool = true) {
        self.story = story
        self.metrics = metrics
        self.linksAndTags = linksAndTags
    }
}

/// Plain Markdown for a CV or a review: one board, one year, or one task. Boards come newest
/// first, as in the sidebar; tasks within a board come oldest first, so they read as a story.
/// Dates use English month names, whatever the Mac's language, so the file is the same everywhere.
public enum MarkdownExport {
    /// `# Board`, its period, then each task as `##`.
    public static func board(
        _ board: Board,
        entries: [Entry],
        options: MarkdownOptions = MarkdownOptions(),
        exportedOn: DayDate
    ) -> String {
        let tasks = chronological(entries.filter { $0.boardId == board.id && !$0.isDeleted })
        var lines = ["# \(inline(board.name))", "", "\(board.period(format)) · \(tasks.count.counted("task"))", ""]
        lines.append("Exported from Tenure on \(format(exportedOn)).")
        for entry in tasks {
            lines.append("")
            lines += entryLines(entry, level: 2, options: options)
        }
        return finish(lines)
    }

    /// `# Year`, then each board with tasks dated in that year as `##`, its tasks as `###`.
    /// A task counts when any day from its date to its end date falls in the year.
    /// `boardId` limits it to one board.
    public static func year(
        _ year: Int,
        boards: [Board],
        entries: [Entry],
        boardId: UUID? = nil,
        options: MarkdownOptions = MarkdownOptions(),
        exportedOn: DayDate
    ) -> String {
        let groups = yearGroups(year, boards: boards, entries: entries, boardId: boardId)
        return grouped(String(year), groups, options: options, exportedOn: exportedOn)
    }

    /// Every board, newest first, as `##` under `# Tenure`, its tasks as `###`.
    public static func all(
        boards: [Board],
        entries: [Entry],
        options: MarkdownOptions = MarkdownOptions(),
        exportedOn: DayDate
    ) -> String {
        let groups = boards.filter { !$0.isDeleted }.sorted(by: Board.timelineOrder).map { board in
            (board: board, entries: chronological(entries.filter { $0.boardId == board.id && !$0.isDeleted }))
        }
        return grouped("Tenure", groups, options: options, exportedOn: exportedOn)
    }

    /// One task as `#`, for the clipboard.
    public static func entry(_ entry: Entry, options: MarkdownOptions = MarkdownOptions()) -> String {
        finish(entryLines(entry, level: 1, options: options))
    }

    /// Tasks that `year(_:...)` would export, per board; boards with none are left out.
    public static func yearGroups(
        _ year: Int,
        boards: [Board],
        entries: [Entry],
        boardId: UUID? = nil
    ) -> [(board: Board, entries: [Entry])] {
        boards
            .filter { !$0.isDeleted && (boardId == nil || $0.id == boardId) }
            .sorted(by: Board.timelineOrder)
            .compactMap { board in
                let tasks = entries.filter { $0.boardId == board.id && !$0.isDeleted && $0.touches(year) }
                return tasks.isEmpty ? nil : (board, chronological(tasks))
            }
    }

    /// Years with at least one task, newest first.
    public static func years(of entries: [Entry]) -> [Int] {
        let years = entries.filter { !$0.isDeleted }.flatMap(\.years)
        return Set(years).sorted(by: >)
    }

    /// "Zalo", "Tenure 2026": a file name, without the extension, safe on any file system.
    public static func fileName(_ title: String) -> String {
        let unsafe = CharacterSet(charactersIn: "/\\:?*\"<>|").union(.newlines).union(.controlCharacters)
        let cleaned = title.unicodeScalars.map { unsafe.contains($0) ? "-" : String($0) }.joined()
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "Tenure" : cleaned
    }

    // MARK: Pieces

    private static func grouped(
        _ title: String,
        _ groups: [(board: Board, entries: [Entry])],
        options: MarkdownOptions,
        exportedOn: DayDate
    ) -> String {
        let total = groups.reduce(0) { $0 + $1.entries.count }
        var lines = [
            "# \(title)", "",
            "Exported from Tenure on \(format(exportedOn)). \(total.counted("task")) from \(groups.count.counted("board")).",
        ]
        for group in groups {
            lines += ["", "## \(inline(group.board.name))", "", group.board.period(format)]
            for entry in group.entries {
                lines.append("")
                lines += entryLines(entry, level: 3, options: options)
            }
        }
        return finish(lines)
    }

    static func entryLines(_ entry: Entry, level: Int, options: MarkdownOptions) -> [String] {
        let heading = String(repeating: "#", count: level)
        var lines = ["\(heading) \(inline(entry.displayName))", ""]
        var facts = [entry.type.title, entry.period(format)]
        if options.linksAndTags, let link = entry.link?.trimmingCharacters(in: .whitespaces), !link.isEmpty {
            facts.append(link.contains("://") ? "<\(link)>" : inline(link))
        }
        lines.append(facts.joined(separator: " · "))
        if options.linksAndTags, !entry.tags.isEmpty {
            lines.append("")
            lines.append("Tags: " + entry.tags.map(inline).joined(separator: ", "))
        }
        if options.story {
            for (part, text) in entry.story {
                lines += ["", "**\(part.title)**", "", text.trimmingCharacters(in: .whitespacesAndNewlines)]
            }
        }
        if options.metrics, !entry.metrics.isEmpty {
            lines += ["", "| Metric | Before | After | Change | Note |", "|---|---|---|---|---|"]
            for metric in entry.metrics {
                let cells = [
                    metric.label,
                    metric.before.map { metric.withUnit($0) } ?? "",
                    metric.withUnit(metric.after),
                    metric.changeText ?? "",
                    metric.note ?? "",
                ]
                lines.append("| " + cells.map(cell).joined(separator: " | ") + " |")
            }
        }
        return lines
    }

    static func format(_ day: DayDate) -> String {
        "\(day.day) \(months[day.month - 1]) \(day.year)"
    }

    static func format(_ month: YearMonth) -> String {
        "\(months[month.month - 1]) \(month.year)"
    }

    private static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    private static func chronological(_ entries: [Entry]) -> [Entry] {
        entries.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    /// One line of text: newlines would break a heading or a list.
    private static func inline(_ text: String) -> String {
        text.components(separatedBy: .newlines).joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    /// A table cell: one line, pipes escaped.
    private static func cell(_ text: String) -> String {
        inline(text).replacingOccurrences(of: "|", with: "\\|")
    }

    private static func finish(_ lines: [String]) -> String {
        lines.joined(separator: "\n") + "\n"
    }
}
