# SearchFeature

Layer: presentation. SPM target: `SearchFeature`.

## Scope

Cmd+K quick search over every task.

## Owns

- `QuickSearchViewModel`, `QuickSearchActions`, `QuickSearchView`

## Must not

- Import a Data module or another feature

## Depends on

Domain, DesignSystem

## Tests

None yet; ranking is covered by `EntrySearch` in DomainTests.
