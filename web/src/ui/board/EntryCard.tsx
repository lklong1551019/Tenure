import { Link } from 'react-router-dom'
import type { YearMonth } from '../../domain/calendar'
import { type Entry, entryTypeTitle } from '../../domain/model'
import { counted, displayName, metricChangeText, story, withUnit } from '../../domain/story'
import { Badge } from '../components/Badge'
import { Icon } from '../components/Icon'
import { parseInline, plainText } from '../components/inlineMarkdown'
import { ChangePill } from '../components/MetricTile'
import { dayMonth, kindTint, linkLabel, longMonth, shortDay } from '../format'
import './board.css'

/** First story part as one plain line. */
export function excerpt(entry: Entry): string | undefined {
  const first = story(entry)[0]
  return (
    first &&
    plainText(parseInline(first.text))
      .split(/\s*\n\s*/)
      .join(' ')
  )
}

interface EntryViewProps {
  entry: Entry
  to: string
  isSelected: boolean
  /** Shown when the view spans every board and there is more than one. */
  boardName?: string
  /** The year the view is filtered to: a task that began earlier says so. */
  filterYear?: number
  /** Under a month heading the date drops its year ("12 Mar"). */
  underMonthHeading?: boolean
}

/**
 * One task in the grid: kind, date, name, the start of its story, and the first metric. A
 * task without a story has a dashed border and says so in its last line.
 */
export function EntryCard(props: EntryViewProps) {
  const { entry, to, isSelected, boardName, filterYear, underMonthHeading } = props
  const text = excerpt(entry)
  const metric = entry.metrics[0]
  const change = metric && metricChangeText(metric)
  return (
    <Link
      to={to}
      className={`entry-card card${isSelected ? ' is-selected' : ''}${text ? '' : ' is-draft'}`}
      aria-current={isSelected}
    >
      <div className="entry-card-top">
        <Badge text={entryTypeTitle(entry.type)} tint={kindTint(entry.type)} />
        <span className="entry-date">
          {underMonthHeading ? dayMonth(entry.date) : shortDay(entry.date)}
        </span>
      </div>
      <h3 className="entry-name">{displayName(entry)}</h3>
      {text && <p className="entry-excerpt">{text}</p>}
      {filterYear !== undefined && entry.date.year < filterYear && (
        <Badge text={`Started in ${entry.date.year}`} tint="amber" />
      )}
      {metric && (
        <div className="entry-metric">
          <span className="entry-metric-label">{metric.label}</span>
          {metric.before && (
            <>
              <span className="entry-muted">{metric.before}</span>
              <Icon name="arrow" size={12} label="to" />
            </>
          )}
          <strong>{withUnit(metric, metric.after)}</strong>
          {change && <ChangePill text={change} />}
        </div>
      )}
      <EntryFooter entry={entry} boardName={boardName} hasStory={text !== undefined} />
    </Link>
  )
}

/** One task in the list: one line, the same facts. */
export function EntryRow({ entry, to, isSelected, boardName }: EntryViewProps) {
  return (
    <Link
      to={to}
      className={`entry-row${isSelected ? ' is-selected' : ''}`}
      aria-current={isSelected}
    >
      <Badge text={entryTypeTitle(entry.type)} tint={kindTint(entry.type)} />
      <span className="entry-row-name">{displayName(entry)}</span>
      {boardName && <span className="entry-row-board">{boardName}</span>}
      {entry.link && (
        <span className="entry-link" title={entry.link}>
          {linkLabel(entry.link)}
        </span>
      )}
      <span className="entry-date">{shortDay(entry.date)}</span>
    </Link>
  )
}

/** The link as a ticket key in the accent color, the tags, the board, and "No story". */
function EntryFooter(props: { entry: Entry; boardName?: string; hasStory: boolean }) {
  const { entry, boardName, hasStory } = props
  if (!entry.link && !boardName && entry.tags.length === 0 && hasStory) return null
  return (
    <div className="entry-footer">
      {entry.link && (
        <span className="entry-link" title={entry.link}>
          <Icon name="link" size={12} />
          {linkLabel(entry.link)}
        </span>
      )}
      {boardName && (
        <span className="entry-footer-board">
          <Icon name="building" size={12} />
          {boardName}
        </span>
      )}
      {entry.tags.slice(0, 3).map((tag) => (
        <span key={tag}>#{tag}</span>
      ))}
      {!hasStory && <span className="entry-no-story">No story</span>}
    </div>
  )
}

/** "October 2026  6 tasks": the heading over one month's tasks in the grid and the list. */
export function MonthHeading({ month, count }: { month: YearMonth; count: number }) {
  return (
    <h2 className="month-heading">
      {longMonth(month)} <span>{counted(count, 'task')}</span>
    </h2>
  )
}
