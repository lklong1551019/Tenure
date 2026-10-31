import type { EntrySort, YearCount } from '../../domain/query'
import { entryTypeTitle } from '../../domain/model'
import { FilterChip } from '../components/FilterChip'
import { Icon } from '../components/Icon'
import { kindTint } from '../format'
import { YearFilterChip } from './YearFilterChip'
import './board.css'

export type Layout = 'grid' | 'list'

const sortTitles: Record<EntrySort, string> = {
  newest: 'Newest first',
  oldest: 'Oldest first',
  nameAscending: 'Name A-Z',
  nameDescending: 'Name Z-A',
}

/** Search, sort, and grid or list; below, the year menu and the kind chips. */
export function Toolbar(props: {
  text: string
  onText: (text: string) => void
  kinds: readonly string[]
  selectedKinds: ReadonlySet<string>
  onToggleKind: (kind: string) => void
  onAllKinds: () => void
  years: readonly YearCount[]
  /** Tasks in view before the year and kind filters, for "All years". */
  total: number
  year: number | undefined
  onYear: (year: number | undefined) => void
  sort: EntrySort
  onSort: (sort: EntrySort) => void
  layout: Layout
  onLayout: (layout: Layout) => void
}) {
  return (
    <div className="toolbar">
      <div className="toolbar-row">
        <label className="toolbar-search">
          <Icon name="search" />
          <span className="visually-hidden">Search tasks</span>
          <input
            type="search"
            className="field"
            placeholder="Search tasks"
            value={props.text}
            onChange={(event) => props.onText(event.target.value)}
          />
        </label>
        <div className="toolbar-controls">
          <label>
            <span className="visually-hidden">Sort</span>
            <select
              className="field"
              value={props.sort}
              onChange={(event) => props.onSort(event.target.value as EntrySort)}
            >
              {Object.entries(sortTitles).map(([sort, title]) => (
                <option key={sort} value={sort}>
                  {title}
                </option>
              ))}
            </select>
          </label>
          <div className="segmented" role="group" aria-label="Layout">
            {(['grid', 'list'] as const).map((layout) => (
              <button
                key={layout}
                type="button"
                className="button button-icon"
                aria-pressed={props.layout === layout}
                onClick={() => props.onLayout(layout)}
              >
                <Icon name={layout} label={layout === 'grid' ? 'Grid' : 'List'} />
              </button>
            ))}
          </div>
        </div>
      </div>
      <div className="toolbar-chips" role="group" aria-label="Filters">
        <YearFilterChip
          years={props.years}
          total={props.total}
          year={props.year}
          onYear={props.onYear}
        />
        <span className="toolbar-divider" aria-hidden="true" />
        <FilterChip
          text="All kinds"
          tint="teal"
          isOn={props.selectedKinds.size === 0}
          onToggle={props.onAllKinds}
        />
        {props.kinds.map((kind) => (
          <FilterChip
            key={kind}
            text={entryTypeTitle(kind)}
            tint={kindTint(kind)}
            isOn={props.selectedKinds.has(kind)}
            onToggle={() => props.onToggleKind(kind)}
          />
        ))}
      </div>
    </div>
  )
}
