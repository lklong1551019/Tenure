# SearchFeature

Layer: presentation. SPM target: `SearchFeature`.

## Scope

Cmd+K quick search over every task.

## Owns

- `QuickSearchViewModel`, `QuickSearchActions`, `QuickSearchView`. Results are ranked once per
  change of the query or the tasks and kept, not recomputed on every read.

## Must not

- Import a Data module or another feature

## Depends on

Domain, DesignSystem

## Tests

None yet; ranking is covered by `EntrySearch` in DomainTests.
