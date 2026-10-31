import Domain
import Foundation
import Persistence
import Testing

/// Fixtures for the web app (`web/`), produced by the Swift code they describe. The web's
/// codec, merge, fingerprint, query, search, and export are ports of these rules, and its
/// tests read the files below and must reproduce them byte for byte.
///
/// Each test compares what the Swift code produces with the committed file, so a rule changed
/// here without the web following fails `swift test`. After a deliberate change, regenerate
/// with `TENURE_WRITE_FIXTURES=1 swift test --package-path Packages --filter WebFixture` and
/// make `npm --prefix web test` pass again.
///
/// No case depends on the time zone: fallback dates that come from `Calendar.current` are
/// left to the web's own tests.
@Suite("Web fixtures")
struct WebFixtureTests {
    static let directory = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "../../web/test/fixtures")
        .standardized

    let codec = LedgerFileCodec()

    @Test func ledgerFiles() throws {
        try check("file-full.json", codec.encode(Samples.full))
        try check("file-empty.json", codec.encode(.empty))
    }

    @Test func tolerantDecoding() throws {
        let decoded = try codec.decode(Data(Samples.tolerantInput.utf8))
        try check("tolerant-input.json", Data(Samples.tolerantInput.utf8))
        try check("tolerant-output.json", codec.encode(decoded))
    }

    @Test func decodeErrors() throws {
        let cases = Samples.decodeInputs.map { name, input in
            let outcome: String?
            do {
                _ = try codec.decode(Data(input.utf8))
                outcome = nil
            } catch LedgerError.unsupportedFormatVersion(let version) {
                outcome = "unsupportedFormatVersion:\(version)"
            } catch {
                outcome = "corruptFile"
            }
            return DecodeCase(name: name, input: input, error: outcome)
        }
        try check("decode-cases.json", json(cases))
    }

    @Test func merges() throws {
        let cases = try Samples.merges.map { sample in
            let merged = MergePolicy.merge(local: sample.local, remote: sample.remote, now: Samples.now)
            let swapped = MergePolicy.merge(local: sample.remote, remote: sample.local, now: Samples.now)
            #expect(merged == swapped, "\(sample.name): merge must not depend on order")
            return MergeCase(
                name: sample.name,
                now: Samples.now.millis,
                local: try text(codec.encode(sample.local)),
                remote: try text(codec.encode(sample.remote)),
                merged: try text(codec.encode(merged))
            )
        }
        try check("merge-cases.json", json(cases))
    }

    @Test func fingerprints() throws {
        let snapshots: [(String, LedgerSnapshot)] =
            [("empty", .empty), ("full", Samples.full)]
            + Samples.merges.map { ($0.name, $0.local) }
        let cases = try snapshots.map { name, snapshot in
            FingerprintCase(
                name: name,
                file: try text(codec.encode(snapshot)),
                fingerprint: String(SnapshotFingerprint.of(snapshot))
            )
        }
        try check("fingerprint-cases.json", json(cases))
    }

    @Test func queriesAndSearch() throws {
        // Read back from the file, as the web does, so both start from entries in file order.
        let file = try codec.encode(Samples.full)
        let entries = try codec.decode(file).liveEntries
        let queries = Samples.queries.map { name, query in
            QueryCase(
                name: name,
                boardId: query.boardId?.uuidString,
                types: query.types.map(\.rawValue).sorted(),
                year: query.year,
                text: query.text,
                sort: query.sort.rawValue,
                result: query.apply(to: entries).map(\.id.uuidString)
            )
        }
        let searches = Samples.searches.map { text in
            SearchCase(text: text, result: EntrySearch.search(text, in: entries).map(\.id.uuidString))
        }
        try check("query-cases.json", json(QueryFixture(file: try text(file), queries: queries, searches: searches)))
    }

    @Test func markdownExports() throws {
        let boards = Samples.full.boards
        let entries = Samples.full.entries
        let day = DayDate(year: 2026, month: 10, day: 31)
        let bare = MarkdownOptions(story: false, metrics: false, linksAndTags: false)
        var cases = [
            ExportCase(name: "all", markdown: MarkdownExport.all(boards: boards, entries: entries, exportedOn: day)),
            ExportCase(
                name: "year 2026",
                markdown: MarkdownExport.year(2026, boards: boards, entries: entries, exportedOn: day)
            ),
            ExportCase(
                name: "year 2026 one board, bare",
                markdown: MarkdownExport.year(
                    2026,
                    boards: boards,
                    entries: entries,
                    boardId: Samples.current.id,
                    options: bare,
                    exportedOn: day
                )
            ),
        ]
        for board in boards where !board.isDeleted {
            cases.append(
                ExportCase(
                    name: "board \(board.name)",
                    markdown: MarkdownExport.board(board, entries: entries, exportedOn: day)
                )
            )
        }
        for entry in entries where !entry.isDeleted {
            cases.append(ExportCase(name: "entry \(entry.id.uuidString)", markdown: MarkdownExport.entry(entry)))
        }
        let years = MarkdownExport.years(of: entries)
        let fileNames = ["Zalo", "a/b:c?", "  ", "Tenure 2026", "line\nbreak"].map {
            FileNameCase(title: $0, fileName: MarkdownExport.fileName($0))
        }
        let metrics = Samples.metricValues.map { before, after, unit in
            let metric = Metric(id: Samples.uuid(0xF0), label: "m", before: before, after: after, unit: unit)
            return MetricCase(
                before: before,
                after: after,
                unit: unit,
                changeText: metric.changeText,
                afterWithUnit: metric.withUnit(after)
            )
        }
        try check(
            "export-cases.json",
            json(
                ExportFixture(
                    file: try text(codec.encode(Samples.full)),
                    exportedOn: day.description,
                    exports: cases,
                    years: years,
                    fileNames: fileNames,
                    metrics: metrics
                )
            )
        )
    }

    // MARK: Writing and comparing

    private func check(_ name: String, _ data: Data) throws {
        let url = Self.directory.appending(path: name)
        if ProcessInfo.processInfo.environment["TENURE_WRITE_FIXTURES"] == "1" {
            try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return
        }
        let committed = try Data(contentsOf: url)
        #expect(committed == data, "\(name) is out of date; see WebFixtureTests for how to regenerate it")
    }

    private func json<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value) + Data("\n".utf8)
    }

    private func text(_ data: Data) throws -> String {
        try #require(String(data: data, encoding: .utf8))
    }
}

// MARK: Fixture shapes

private struct DecodeCase: Encodable {
    let name: String
    let input: String
    let error: String?
}

private struct MergeCase: Encodable {
    let name: String
    let now: Int64
    let local: String
    let remote: String
    let merged: String
}

private struct FingerprintCase: Encodable {
    let name: String
    let file: String
    /// Decimal: a 64-bit value does not fit a JSON number the web can read exactly.
    let fingerprint: String
}

private struct QueryCase: Encodable {
    let name: String
    let boardId: String?
    let types: [String]
    let year: Int?
    let text: String
    let sort: String
    let result: [String]
}

private struct SearchCase: Encodable {
    let text: String
    let result: [String]
}

private struct QueryFixture: Encodable {
    let file: String
    let queries: [QueryCase]
    let searches: [SearchCase]
}

private struct ExportCase: Encodable {
    let name: String
    let markdown: String
}

private struct FileNameCase: Encodable {
    let title: String
    let fileName: String
}

private struct MetricCase: Encodable {
    let before: String?
    let after: String
    let unit: String?
    let changeText: String?
    let afterWithUnit: String
}

private struct ExportFixture: Encodable {
    let file: String
    let exportedOn: String
    let exports: [ExportCase]
    let years: [Int]
    let fileNames: [FileNameCase]
    let metrics: [MetricCase]
}

// MARK: Samples

private enum Samples {
    static let now = Timestamp(millis: 1_790_000_000_000)

    static func uuid(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012X", n))!
    }

    static func stamp(_ offset: Int64) -> Timestamp {
        Timestamp(millis: 1_780_000_000_000 + offset)
    }

    static let former = Board(
        id: uuid(0xB1),
        name: "Company A",
        start: YearMonth(year: 2017, month: 7),
        end: YearMonth(year: 2019, month: 8),
        createdAt: stamp(1),
        updatedAt: stamp(2)
    )

    static let current = Board(
        id: uuid(0xB2),
        name: "Zalo / VNG \"core\"",
        start: YearMonth(year: 2019, month: 9),
        createdAt: stamp(3),
        updatedAt: stamp(4)
    )

    static let removedBoard = Board(
        id: uuid(0xB3),
        name: "Gone",
        start: YearMonth(year: 2015, month: 1),
        end: YearMonth(year: 2016, month: 2),
        createdAt: stamp(5),
        updatedAt: stamp(9),
        deletedAt: stamp(9)
    )

    static let entries: [Entry] = [
        Entry(
            id: uuid(0xE1),
            boardId: current.id,
            name: "Cold start \"fast\" path",
            link: "https://jira.example.com/browse/T-1?a=b&c=d",
            type: .product,
            date: DayDate(year: 2026, month: 3, day: 12),
            endDate: DayDate(year: 2026, month: 4, day: 2),
            tags: ["perf", "android/ios", "Việt"],
            problem: "Launch took **1.8 s** on\nmid-range phones.\n\n- one\n- two",
            why: "Users in Việt Nam 🇻🇳 open it many times a day.",
            solution:
                "Lazy init, a `tab\there`, a back\\slash, a bell \u{07}, a nul-ish \u{01}, \u{08}\u{0C}\u{1B}\u{7F}\r\u{2028}\u{2029}\u{FEFF}.",
            impact: "",
            difficulties: "  Profiling on <b>real</b> devices  ",
            metrics: [
                Metric(
                    id: uuid(0xA1),
                    label: "Cold start",
                    before: "1.8",
                    after: "0.9",
                    unit: "s",
                    note: "Pixel 7, n=20"
                ),
                Metric(id: uuid(0xA2), label: "Crash | rate", after: "~0.1%"),
                Metric(id: uuid(0xA3), label: "Requests", before: "1,200", after: "1,350", unit: " "),
            ],
            createdAt: stamp(10),
            updatedAt: stamp(11)
        ),
        Entry(
            id: uuid(0xE2),
            boardId: current.id,
            name: "Fix crash on resume",
            type: .bugFix,
            date: DayDate(year: 2025, month: 12, day: 31),
            endDate: DayDate(year: 2026, month: 1, day: 2),
            problem: "NPE",
            createdAt: stamp(12),
            updatedAt: stamp(13)
        ),
        Entry(
            id: uuid(0xE3),
            boardId: current.id,
            name: "",
            type: EntryType(rawValue: "research"),
            date: DayDate(year: 2026, month: 3, day: 12),
            createdAt: stamp(14),
            updatedAt: stamp(15)
        ),
        Entry(
            id: uuid(0xE4),
            boardId: current.id,
            name: "Deleted task",
            date: DayDate(year: 2026, month: 1, day: 1),
            createdAt: stamp(16),
            updatedAt: stamp(18),
            deletedAt: stamp(18)
        ),
        Entry(
            id: uuid(0xE5),
            boardId: former.id,
            name: "Write-up on caching",
            link: "jira/T-9",
            type: .findings,
            date: DayDate(year: 2018, month: 5, day: 1),
            tags: ["cache"],
            impact: "Saved [money](https://example.com) and [x](javascript:alert(1)).",
            createdAt: stamp(19),
            updatedAt: stamp(20)
        ),
        Entry(
            id: uuid(0xE6),
            boardId: former.id,
            name: "Task 10",
            date: DayDate(year: 2018, month: 6, day: 1),
            createdAt: stamp(21),
            updatedAt: stamp(22)
        ),
        Entry(
            id: uuid(0xE7),
            boardId: former.id,
            name: "Task 2",
            date: DayDate(year: 2018, month: 6, day: 1),
            createdAt: stamp(23),
            updatedAt: stamp(24)
        ),
        Entry(
            id: uuid(0xE8),
            boardId: former.id,
            name: "apple pie",
            type: .dev,
            date: DayDate(year: 2018, month: 6, day: 1),
            tags: ["Đà Lạt"],
            createdAt: stamp(25),
            updatedAt: stamp(26)
        ),
        Entry(
            id: uuid(0xE9),
            boardId: removedBoard.id,
            name: "On a deleted board",
            date: DayDate(year: 2015, month: 6, day: 1),
            createdAt: stamp(27),
            updatedAt: stamp(28)
        ),
    ]

    static let full = LedgerSnapshot(boards: [current, removedBoard, former], entries: entries.reversed())

    // MARK: Tolerant decoding

    /// Every optional field malformed in some way; the dates that fall back to `updatedAt` are
    /// left out, since that fallback reads the time zone.
    static let tolerantInput = """
        {
          "format": "tenure",
          "version": 1,
          "extra": {"from": "a newer build"},
          "boards": [
            {"id": "00000000-0000-4000-8000-0000000000c1", "updatedAt": 1780000000000, "name": 5,
             "start": "2017-07", "end": "2019-13", "createdAt": "yesterday", "deletedAt": null, "color": "red"},
            {"id": "00000000-0000-4000-8000-0000000000C2", "updatedAt": 1780000000001, "start": "2018-1",
             "end": "2020-02", "deletedAt": 1780000000001}
          ],
          "entries": [
            {"id": "00000000-0000-4000-8000-0000000000d1", "boardId": "00000000-0000-4000-8000-0000000000c1",
             "updatedAt": 1780000000002, "name": null, "link": 42, "type": 7, "date": "2026-02-30",
             "endDate": "2026-1-5", "tags": ["a", 1], "problem": ["x"], "why": "ok", "solution": true,
             "metrics": [{"id": "00000000-0000-4000-8000-0000000000a9", "label": 3, "after": 3, "before": "1"}],
             "createdAt": 1780000000000.0},
            {"id": "00000000-0000-4000-8000-0000000000d2", "boardId": "00000000-0000-4000-8000-0000000000c1",
             "updatedAt": 1780000000003, "name": "Bad metrics", "type": "bugFix", "date": "2026-03-01",
             "endDate": "nope", "tags": [], "metrics": [{"id": "00000000-0000-4000-8000-0000000000aa",
             "after": "1"}, "garbage"], "unknown": 1},
            {"id": "00000000-0000-4000-8000-0000000000d3", "boardId": "00000000-0000-4000-8000-0000000000c2",
             "updatedAt": 1780000000004, "date": "2026-03-01", "endDate": null, "link": "",
             "metrics": [{"id": "00000000-0000-4000-8000-0000000000ab", "label": "x", "after": "1", "unit": null, "note": "n"}]}
          ]
        }
        """

    // MARK: Decode errors and probes

    static let decodeInputs: [(String, String)] = [
        ("not json", "nope"),
        ("top-level array", "[]"),
        ("wrong format", #"{"format": "other", "version": 1, "boards": [], "entries": []}"#),
        ("newer version", #"{"format": "tenure", "version": 2, "boards": [], "entries": []}"#),
        ("newer version, unreadable body", #"{"format": "tenure", "version": 3}"#),
        ("version as text", #"{"format": "tenure", "version": "1", "boards": [], "entries": []}"#),
        ("version zero", #"{"format": "tenure", "version": 0, "boards": [], "entries": []}"#),
        ("version float", #"{"format": "tenure", "version": 1.0, "boards": [], "entries": []}"#),
        ("missing entries", #"{"format": "tenure", "version": 1, "boards": []}"#),
        ("boards null", #"{"format": "tenure", "version": 1, "boards": null, "entries": []}"#),
        (
            "duplicate board ids",
            #"{"format": "tenure", "version": 1, "entries": [], "boards": [{"id": "00000000-0000-4000-8000-000000000001", "updatedAt": 1}, {"id": "00000000-0000-4000-8000-000000000001", "updatedAt": 2}]}"#
        ),
        (
            "duplicate ids differing in case",
            #"{"format": "tenure", "version": 1, "entries": [], "boards": [{"id": "00000000-0000-4000-8000-00000000000a", "updatedAt": 1}, {"id": "00000000-0000-4000-8000-00000000000A", "updatedAt": 2}]}"#
        ),
        (
            "same id as board and entry",
            #"{"format": "tenure", "version": 1, "boards": [{"id": "00000000-0000-4000-8000-000000000001", "updatedAt": 1, "start": "2020-01"}], "entries": [{"id": "00000000-0000-4000-8000-000000000001", "boardId": "00000000-0000-4000-8000-000000000001", "updatedAt": 1, "date": "2020-01-01"}]}"#
        ),
        (
            "board without updatedAt",
            #"{"format": "tenure", "version": 1, "entries": [], "boards": [{"id": "00000000-0000-4000-8000-000000000001"}]}"#
        ),
        (
            "board with a bad id",
            #"{"format": "tenure", "version": 1, "entries": [], "boards": [{"id": "x", "updatedAt": 1}]}"#
        ),
        (
            "entry without boardId",
            #"{"format": "tenure", "version": 1, "boards": [], "entries": [{"id": "00000000-0000-4000-8000-000000000001", "updatedAt": 1, "date": "2020-01-01"}]}"#
        ),
        (
            "entry on a missing board",
            #"{"format": "tenure", "version": 1, "boards": [], "entries": [{"id": "00000000-0000-4000-8000-000000000001", "boardId": "00000000-0000-4000-8000-000000000009", "updatedAt": 1, "date": "2020-01-01"}]}"#
        ),
        (
            "updatedAt with a fraction",
            #"{"format": "tenure", "version": 1, "entries": [], "boards": [{"id": "00000000-0000-4000-8000-000000000001", "updatedAt": 1.5}]}"#
        ),
        (
            "updatedAt written as 1.0",
            #"{"format": "tenure", "version": 1, "entries": [], "boards": [{"id": "00000000-0000-4000-8000-000000000001", "updatedAt": 1.0, "start": "2020-01"}]}"#
        ),
        (
            "updatedAt as text",
            #"{"format": "tenure", "version": 1, "entries": [], "boards": [{"id": "00000000-0000-4000-8000-000000000001", "updatedAt": "1"}]}"#
        ),
        (
            "board as a number",
            #"{"format": "tenure", "version": 1, "entries": [], "boards": [1]}"#
        ),
    ]

    // MARK: Merge

    struct MergeSample {
        let name: String
        let local: LedgerSnapshot
        let remote: LedgerSnapshot
    }

    static func entry(_ n: Int, name: String, updated: Int64, deleted: Bool = false) -> Entry {
        Entry(
            id: uuid(n),
            boardId: current.id,
            name: name,
            date: DayDate(year: 2026, month: 1, day: 1),
            createdAt: stamp(0),
            updatedAt: stamp(updated),
            deletedAt: deleted ? stamp(updated) : nil
        )
    }

    static let merges: [MergeSample] = {
        let old = Timestamp(millis: now.millis - 91 * Timestamp.millisPerDay)
        let recent = Timestamp(millis: now.millis - 89 * Timestamp.millisPerDay)
        var oldTombstone = entry(0x31, name: "old delete", updated: 0, deleted: true)
        oldTombstone.updatedAt = old
        oldTombstone.deletedAt = old
        var recentTombstone = entry(0x32, name: "recent delete", updated: 0, deleted: true)
        recentTombstone.updatedAt = recent
        recentTombstone.deletedAt = recent
        var renamedBoard = current
        renamedBoard.name = "Zalo"
        renamedBoard.updatedAt = stamp(100)
        return [
            MergeSample(
                name: "disjoint items are all kept",
                local: LedgerSnapshot(boards: [current], entries: [entry(0x11, name: "local", updated: 1)]),
                remote: LedgerSnapshot(boards: [former], entries: [entry(0x12, name: "remote", updated: 1)])
            ),
            MergeSample(
                name: "newer edit wins",
                local: LedgerSnapshot(boards: [current], entries: [entry(0x13, name: "older", updated: 1)]),
                remote: LedgerSnapshot(boards: [renamedBoard], entries: [entry(0x13, name: "newer", updated: 2)])
            ),
            MergeSample(
                name: "newer edit beats an older delete",
                local: LedgerSnapshot(entries: [entry(0x14, name: "deleted", updated: 1, deleted: true)]),
                remote: LedgerSnapshot(entries: [entry(0x14, name: "edited later", updated: 2)])
            ),
            MergeSample(
                name: "delete beats an edit at the same instant",
                local: LedgerSnapshot(entries: [entry(0x15, name: "edited", updated: 5)]),
                remote: LedgerSnapshot(entries: [entry(0x15, name: "deleted", updated: 5, deleted: true)])
            ),
            MergeSample(
                name: "tie: escaped slash sorts after a digit",
                local: LedgerSnapshot(entries: [entry(0x16, name: "a/b", updated: 5)]),
                remote: LedgerSnapshot(entries: [entry(0x16, name: "a0b", updated: 5)])
            ),
            MergeSample(
                name: "tie: UTF-8 bytes, not UTF-16 units",
                local: LedgerSnapshot(entries: [entry(0x17, name: "\u{FF5E}", updated: 5)]),
                remote: LedgerSnapshot(entries: [entry(0x17, name: "😀", updated: 5)])
            ),
            MergeSample(
                name: "tie: accented letter",
                local: LedgerSnapshot(entries: [entry(0x18, name: "Việt", updated: 5)]),
                remote: LedgerSnapshot(entries: [entry(0x18, name: "Viet", updated: 5)])
            ),
            MergeSample(
                name: "tie: quote and control characters",
                local: LedgerSnapshot(entries: [entry(0x19, name: "say \"hi\"\n", updated: 5)]),
                remote: LedgerSnapshot(entries: [entry(0x19, name: "say \u{01}hi", updated: 5)])
            ),
            MergeSample(
                name: "tie: both deleted",
                local: LedgerSnapshot(entries: [entry(0x1A, name: "one", updated: 5, deleted: true)]),
                remote: LedgerSnapshot(entries: [entry(0x1A, name: "two", updated: 5, deleted: true)])
            ),
            MergeSample(
                name: "tie: optional field present on one side",
                local: LedgerSnapshot(entries: [entry(0x1B, name: "x", updated: 5)]),
                remote: LedgerSnapshot(entries: [
                    {
                        var linked = entry(0x1B, name: "x", updated: 5)
                        linked.link = "https://a.example/x"
                        return linked
                    }()
                ])
            ),
            MergeSample(
                name: "tombstones older than 90 days are purged",
                local: LedgerSnapshot(entries: [oldTombstone, recentTombstone]),
                remote: LedgerSnapshot(entries: [entry(0x33, name: "live", updated: 1)])
            ),
            MergeSample(
                name: "full against empty",
                local: full,
                remote: .empty
            ),
        ]
    }()

    // MARK: Query and search

    static let queries: [(String, EntryQuery)] = [
        ("everything, newest", EntryQuery()),
        ("everything, oldest", EntryQuery(sort: .oldest)),
        ("by name", EntryQuery(sort: .nameAscending)),
        ("by name, descending", EntryQuery(sort: .nameDescending)),
        ("one board", EntryQuery(boardId: former.id)),
        ("kinds", EntryQuery(types: [.dev, .bugFix])),
        ("unknown kind", EntryQuery(types: [EntryType(rawValue: "research")])),
        ("year 2026 spans", EntryQuery(year: 2026)),
        ("year 2025", EntryQuery(year: 2025)),
        ("text", EntryQuery(text: "task")),
        ("text and board", EntryQuery(boardId: former.id, text: "  a  ")),
        ("text with no match", EntryQuery(text: "zzz")),
    ]

    static let searches = [
        "", "cold", "start", "fast", "perf", "jira", "prod", "bug", "viet", "VIỆT", "da lat", "đà", "tsk",
        "task 2", "c s", "ｃｏｌｄ",
    ]

    static let metricValues: [(String?, String, String?)] = [
        ("18", "10", "ms"), ("1.8", "0.9", "s"), ("100", "112", nil), ("200", "201", nil), ("1000", "1001", nil),
        ("0", "5", nil), (nil, "5", nil), ("18ms", "10", nil), ("1,200", "1,350", " "), (" 18 ", " 9 ", nil),
        ("-4", "-2", nil), ("3", "3", nil), ("1", "1.0001", nil), ("p50", "p90", nil),
    ]
}
