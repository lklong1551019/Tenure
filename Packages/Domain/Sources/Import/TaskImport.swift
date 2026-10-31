import Foundation

/// One row of an import, read and checked.
public struct ImportRow: Sendable, Hashable, Identifiable {
    public enum Status: Sendable, Hashable {
        case ready
        case missingName
        case missingDate
        /// The date column held this, which reads as no date.
        case unreadableDate(String)
        case endBeforeStart
        /// The board already has a task with this name and link, or an earlier row does.
        case duplicate
    }

    /// 1-based position among the data rows, for pointing at a row in the preview.
    public let line: Int
    public let name: String
    public let link: String?
    /// A second column that is not a link, kept as the task's problem.
    public let note: String?
    public let date: DayDate?
    public let endDate: DayDate?
    public let status: Status

    public var id: Int { line }
    public var isReady: Bool { status == .ready }
}

/// Turns rows copied from a spreadsheet into tasks. Columns, in order: name, link (or a note
/// when it is not a link), date, end date; only name and date are required, and a first row
/// headed "Name" is skipped. Tab-separated text (what Excel and Numbers put on the clipboard)
/// or CSV; a quoted cell may span lines. Dates read as 2025-03-12, 2025/03/12, or 12/03/2025
/// (day first).
public enum TaskImport {
    /// Reads `text` and checks each row against `existing` tasks on the target board.
    public static func review(_ text: String, boardId: UUID, existing: [Entry]) -> [ImportRow] {
        var seen = Set(existing.filter { $0.boardId == boardId && !$0.isDeleted }.map { key($0.name, $0.link) })
        var records = records(in: text)
        if let first = records.first?.first, ["name", "task", "title"].contains(clean(first).lowercased()) {
            records.removeFirst()
        }
        return records.enumerated().map { index, cells in
            let cell = { (column: Int) in column < cells.count ? cells[column] : "" }
            let name = clean(cell(0))
            let second = cell(1).trimmingCharacters(in: .whitespacesAndNewlines)
            let isLink = second.contains("://") || second.lowercased().hasPrefix("www.")
            let link = isLink ? second : nil
            let dateText = clean(cell(2))
            let date = parseDate(dateText)
            let endDate = parseDate(clean(cell(3)))
            let status: ImportRow.Status
            if name.isEmpty {
                status = .missingName
            } else if dateText.isEmpty {
                status = .missingDate
            } else if date == nil {
                status = .unreadableDate(dateText)
            } else if let date, let endDate, endDate < date {
                status = .endBeforeStart
            } else if !seen.insert(key(name, link)).inserted {
                status = .duplicate
            } else {
                status = .ready
            }
            return ImportRow(
                line: index + 1,
                name: name,
                link: link,
                note: isLink || second.isEmpty ? nil : second,
                date: date,
                endDate: endDate,
                status: status
            )
        }
    }

    /// The ready rows as new tasks of `type` on `boardId`, in row order.
    public static func entries(
        from rows: [ImportRow],
        boardId: UUID,
        type: EntryType,
        createdAt: Timestamp
    ) -> [Entry] {
        rows.compactMap { row in
            guard row.isReady, let date = row.date else { return nil }
            return Entry(
                boardId: boardId,
                name: row.name,
                link: row.link,
                type: type,
                date: date,
                endDate: row.endDate == date ? nil : row.endDate,
                problem: row.note ?? "",
                createdAt: createdAt
            )
        }
    }

    /// "2025-03-12", "2025/03/12", "12/03/2025", "12-03-2025", "12.03.2025"; nil for anything
    /// else or a day that does not exist.
    public static func parseDate(_ text: String) -> DayDate? {
        let parts = text.split(whereSeparator: { "-/.".contains($0) }).map { Int($0) }
        guard parts.count == 3, let a = parts[0], let b = parts[1], let c = parts[2] else { return nil }
        let (year, month, day) =
            text.split(whereSeparator: { "-/.".contains($0) })[0].count == 4 ? (a, b, c) : (c, b, a)
        guard CalendarYears.valid.contains(year), (1...12).contains(month), (1...31).contains(day) else { return nil }
        let components = DateComponents(year: year, month: month, day: day)
        guard components.isValidDate(in: Calendar(identifier: .gregorian)) else { return nil }
        return DayDate(year: year, month: month, day: day)
    }

    // MARK: Pieces

    /// Splits into rows of cells: tabs if the text has any, otherwise commas. A cell in double
    /// quotes may hold the separator and line breaks; `""` inside it is one quote.
    static func records(in text: String) -> [[String]] {
        let separator: Character = text.contains("\t") ? "\t" : ","
        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var inQuotes = false
        var atFieldStart = true
        var characters = text.makeIterator()
        var pending: Character?

        func endRecord() {
            record.append(field)
            if record.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                records.append(record)
            }
            record = []
            field = ""
        }

        while let character = pending ?? characters.next() {
            pending = nil
            if inQuotes {
                if character == "\"" {
                    let next = characters.next()
                    if next == "\"" {
                        field.append("\"")
                    } else {
                        inQuotes = false
                        pending = next
                    }
                } else {
                    field.append(character)
                }
                continue
            }
            switch character {
            case "\"" where atFieldStart:
                inQuotes = true
                atFieldStart = false
            case separator:
                record.append(field)
                field = ""
                atFieldStart = true
            case "\n", "\r\n", "\r":
                endRecord()
                atFieldStart = true
            default:
                field.append(character)
                atFieldStart = false
            }
        }
        if !field.isEmpty || !record.isEmpty { endRecord() }
        return records
    }

    /// One line, single spaces: a name pasted from a wrapped cell reads as one.
    private static func clean(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static func key(_ name: String, _ link: String?) -> String {
        clean(name).lowercased() + "\u{1F}" + (link?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
    }
}
