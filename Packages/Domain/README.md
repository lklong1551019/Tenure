# Domain

Layer: domain. SPM target: `Domain`.

## Scope

What Tenure is about, free of storage, network, and UI: boards, entries, the rules that
change them, and how two copies merge and sync.

## Owns

- Entities: `Board`, `Entry`, `EntryType`, `Metric`, `YearMonth`, `DayDate`, `LedgerSnapshot`;
  tolerant decoding (a bad field falls back, never fails the file)
- `LedgerStore`: stamps, persists, then applies each change; publishes snapshots
- `EntryQuery` (board, kinds, text, sort) and `EntrySearch` (ranked search for Cmd+K)
- `MarkdownExport`: a board, a year, every board, or one task as Markdown; metric change (`-44%`)
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

`DomainTests` (32 tests): model round trips and tolerance, merge rules, store stamping, Markdown export,
cascade delete and failed saves, query sort and filters, search ranking, two-Mac sync with an
in-memory remote (convergence, deletes, interleaved uploads, refused remotes, error mapping).
