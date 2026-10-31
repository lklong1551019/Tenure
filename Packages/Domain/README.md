# Domain

Layer: domain. SPM target: `Domain`.

## Scope

What Tenure is about, free of storage, network, and UI: boards, entries, the rules that
change them, and how two copies merge and sync.

## Owns

- Entities: `Board`, `Entry`, `EntryType`, `Metric`, `YearMonth`, `DayDate`, `LedgerSnapshot`;
  tolerant decoding (a bad field falls back, never fails the file)
- `StoryPart` and the shared rules in `Entry+Story.swift`: `Entry.story`, `displayName`,
  `years` and `touches(_:)` (a span counts in every year it covers), `period(_:)`,
  `Board.period(_:)`, `Int.counted(_:)`, `Metric.change`
- `CalendarYears.valid` (1...9999): a date outside it reads as invalid, so a typo never makes
  the year menu or an export loop over billions of years
- `LedgerStore`: stamps, persists, then applies each change; publishes snapshots (a slow
  reader gets only the newest, never a queue)
- `EntryQuery` (board, kinds, year, text, sort; splits the text once and compares names only
  when needed) and `EntrySearch` (ranked search for Cmd+K)
- `MarkdownExport`: a board, a year, every board, or one task as Markdown; metric change (`-44%`)
- `Release`, `UpdateCheck` (decode the published changelog: at most 256 KB, dotted-number
  versions only, at most 20 newer releases shown; compare `YY.MM.NN` versions), `ReleaseFeedPort`
- `MergePolicy`: per-item last-writer-wins, tombstones, 90-day purge
- `SyncLedger`, `SyncScheduler`, `SnapshotFingerprint`, `RemoteLedgerCheck`
- Ports: `LedgerRepository`, `LedgerCodecPort`, `RemoteStorePort`, `DriveAccountPort`,
  `SyncStatePort`, `ClockPort`, `RandomPort`

## Must not

- Import anything but Foundation
- Know about files, JSON layout on disk, Google, or SwiftUI

## Depends on

Nothing.

## Tests

`DomainTests` (38 tests): model round trips and tolerance, merge rules, store stamping, Markdown
export, update check (version order, newer releases, tolerant changelog, malformed versions, size
limit), out-of-range years,
cascade delete and failed saves, query sort and filters (year included), search ranking, two-Mac sync with an
in-memory remote (convergence, deletes, interleaved uploads, refused remotes, error mapping).
