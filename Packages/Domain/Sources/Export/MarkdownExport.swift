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
        var lines = ["# \(inline(board.name))", "", "\(period(of: board)) · \(count(tasks.count))", ""]
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
        let years = entries.filter { !$0.isDeleted }.flatMap { entry in
            Array(entry.date.year...max(entry.date.year, entry.endDate?.year ?? entry.date.year))
        }
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
        let boardCount = groups.count == 1 ? "1 board" : "\(groups.count) boards"
        var lines = [
            "# \(title)", "", "Exported from Tenure on \(format(exportedOn)). \(count(total)) from \(boardCount).",
        ]
        for group in groups {
            lines += ["", "## \(inline(group.board.name))", "", period(of: group.board)]
            for entry in group.entries {
                lines.append("")
                lines += entryLines(entry, level: 3, options: options)
            }
        }
        return finish(lines)
    }

    static func entryLines(_ entry: Entry, level: Int, options: MarkdownOptions) -> [String] {
        let heading = String(repeating: "#", count: level)
        var lines = ["\(heading) \(inline(entry.name.isEmpty ? "Untitled" : entry.name))", ""]
        var facts = [entry.type.title, period(of: entry)]
        if options.linksAndTags, let link = entry.link?.trimmingCharacters(in: .whitespaces), !link.isEmpty {
            facts.append(link.contains("://") ? "<\(link)>" : inline(link))
        }
        lines.append(facts.joined(separator: " · "))
        if options.linksAndTags, !entry.tags.isEmpty {
            lines.append("")
            lines.append("Tags: " + entry.tags.map(inline).joined(separator: ", "))
        }
        if options.story {
            for (title, text) in entry.story {
                lines += ["", "**\(title)**", "", text.trimmingCharacters(in: .whitespacesAndNewlines)]
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

    private static func period(of board: Board) -> String {
        "\(format(board.start)) - \(board.end.map(format) ?? "now")"
    }

    private static func period(of entry: Entry) -> String {
        guard let end = entry.endDate, end != entry.date else { return format(entry.date) }
        return "\(format(entry.date)) - \(format(end))"
    }

    private static func count(_ value: Int) -> String {
        value == 1 ? "1 task" : "\(value) tasks"
    }

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

extension Entry {
    /// The five story parts in order, empty ones left out.
    public var story: [(title: String, text: String)] {
        [
            ("Problem", problem),
            ("Why", why),
            ("Solution", solution),
            ("Impact", impact),
            ("Difficulties and how they were solved", difficulties),
        ]
        .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func touches(_ year: Int) -> Bool {
        let end = max(date.year, endDate?.year ?? date.year)
        return (date.year...end).contains(year)
    }
}

extension Metric {
    /// Change from before to after, as a fraction: -0.44 for 18 to 10. Nil unless both are
    /// plain numbers and before is not zero.
    public var change: Double? {
        guard let before = before.flatMap(Self.number), let after = Self.number(after), before != 0 else {
            return nil
        }
        return (after - before) / abs(before)
    }

    /// "-44%", "+12%", "+0.5%".
    public var changeText: String? {
        guard let change else { return nil }
        let percent = change * 100
        let rounded = abs(percent) >= 10 ? percent.rounded() : (percent * 10).rounded() / 10
        let digits = rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
        return (rounded > 0 ? "+" : "") + digits + "%"
    }

    /// "18 ms"; the value alone when there is no unit.
    public func withUnit(_ value: String) -> String {
        guard let unit, !unit.trimmingCharacters(in: .whitespaces).isEmpty else { return value }
        return "\(value) \(unit)"
    }

    /// "1,200" and " 18 " read as numbers; "18ms" does not.
    private static func number(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces))
    }
}
