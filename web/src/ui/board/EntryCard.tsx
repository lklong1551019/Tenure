import { Link } from 'react-router-dom'
import { type Entry, entryTypeTitle } from '../../domain/model'
import { displayName, metricChangeText, story, withUnit } from '../../domain/story'
import { Badge } from '../components/Badge'
import { Icon } from '../components/Icon'
import { parseInline, plainText } from '../components/inlineMarkdown'
import { ChangePill } from '../components/MetricTile'
import { kindTint, shortDay } from '../format'
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
  /** Shown when the view spans every board. */
  boardName?: string
  /** The year the view is filtered to: a task that began earlier says so. */
  filterYear?: number
}

/** One task in the grid: kind, date, name, the start of its story, and the first metric. */
export function EntryCard({ entry, to, isSelected, boardName, filterYear }: EntryViewProps) {
  const text = excerpt(entry)
  const metric = entry.metrics[0]
  const change = metric && metricChangeText(metric)
  return (
    <Link
      to={to}
      className={`entry-card card${isSelected ? ' is-selected' : ''}`}
      aria-current={isSelected}
    >
      <div className="entry-card-top">
        <Badge text={entryTypeTitle(entry.type)} tint={kindTint(entry.type)} />
        <span className="entry-date">{shortDay(entry.date)}</span>
      </div>
      <h3 className="entry-name">{displayName(entry)}</h3>
      {text ? (
        <p className="entry-excerpt">{text}</p>
      ) : (
        <p className="entry-excerpt is-empty">No write-up yet.</p>
      )}
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
      <EntryFooter entry={entry} boardName={boardName} />
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
      <span className="entry-date">{shortDay(entry.date)}</span>
    </Link>
  )
}

/**
 * A link split so its middle gives way, as the Mac card's does: the head shrinks to an
 * ellipsis, the tail (the last path part, often a ticket key) stays whole.
 */
export function linkParts(link: string): [string, string] {
  const cut = Math.max(link.length - 16, link.lastIndexOf('/', link.length - 2) + 1)
  return [link.slice(0, cut), link.slice(cut)]
}

/** The link on a line of its own, in the accent color, so it never reads as a tag. */
function EntryLink({ link }: { link: string }) {
  const [head, tail] = linkParts(link)
  return (
    <div className="entry-link" title={link}>
      <Icon name="link" size={12} />
      <span className="entry-link-text">
        <span className="entry-link-head">{head}</span>
        <span className="entry-link-tail">{tail}</span>
      </span>
    </div>
  )
}

function EntryFooter({ entry, boardName }: { entry: Entry; boardName?: string }) {
  return (
    <>
      {entry.link && <EntryLink link={entry.link} />}
      {(boardName || entry.tags.length > 0) && (
        <div className="entry-footer">
          {boardName && (
            <span className="entry-footer-board">
              <Icon name="building" size={12} />
              {boardName}
            </span>
          )}
          {entry.tags.slice(0, 3).map((tag) => (
            <span key={tag}>#{tag}</span>
          ))}
        </div>
      )}
    </>
  )
}
