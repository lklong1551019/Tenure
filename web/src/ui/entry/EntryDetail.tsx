import type { ReactNode } from 'react'
import { type Entry, entryTypeTitle } from '../../domain/model'
import { displayName, entryPeriod, story, storyPartTitles } from '../../domain/story'
import { Badge } from '../components/Badge'
import { Icon } from '../components/Icon'
import { MetricTile } from '../components/MetricTile'
import { StoryText } from '../components/StoryText'
import { kindTint, shortDay, storyTints, taskLinkUrl } from '../format'
import './entry.css'

/** The whole story of one task. */
export function EntryDetail(props: {
  entry: Entry
  boardName: string
  canEdit: boolean
  onEdit: () => void
  onDelete: () => void
  onCopy: () => void
  /** Back to the list on a phone, where the detail takes the whole screen. */
  backTo: ReactNode
}) {
  const { entry } = props
  const sections = story(entry)
  const href = taskLinkUrl(entry.link)
  return (
    <article className="entry-detail" aria-label={displayName(entry)}>
      <div className="entry-detail-actions">
        {props.backTo}
        <span className="spacer" />
        <button type="button" className="button" onClick={props.onCopy}>
          <Icon name="copy" />
          <span className="label-wide">Copy as Markdown</span>
        </button>
        {props.canEdit && (
          <>
            <button type="button" className="button" onClick={props.onEdit}>
              <Icon name="pencil" />
              Edit
            </button>
            <button
              type="button"
              className="button button-danger button-icon"
              onClick={props.onDelete}
            >
              <Icon name="trash" label="Delete task" />
            </button>
          </>
        )}
      </div>
      <header className="entry-detail-header">
        <Badge text={entryTypeTitle(entry.type)} tint={kindTint(entry.type)} />
        <h1>{displayName(entry)}</h1>
        <div className="meta-row">
          <span className="meta-chip">
            <Icon name="calendar" size={14} />
            {entryPeriod(entry, shortDay)}
          </span>
          <span className="meta-chip">
            <Icon name="building" size={14} />
            {props.boardName}
          </span>
          {entry.link &&
            (href ? (
              <a
                className="meta-chip tint-teal"
                href={href}
                target="_blank"
                rel="noopener noreferrer"
                title={entry.link}
              >
                <Icon name="link" size={14} />
                <span className="meta-chip-text">{entry.link}</span>
              </a>
            ) : (
              <span className="meta-chip" title={entry.link}>
                <Icon name="link" size={14} />
                <span className="meta-chip-text">{entry.link}</span>
              </span>
            ))}
          {entry.tags.map((tag) => (
            <span key={tag} className="tag">
              #{tag}
            </span>
          ))}
        </div>
      </header>
      {sections.length === 0 ? (
        <div className="empty-story">
          <strong>No write-up yet</strong>
          <p>
            Add the problem, why it mattered, the solution, the impact, and the numbers that prove
            it.
          </p>
          {props.canEdit && (
            <button type="button" className="button" onClick={props.onEdit}>
              Write the story
            </button>
          )}
        </div>
      ) : (
        sections.map(({ part, text }) => (
          <section key={part} className="story-section">
            <span className={`story-mark tint-${storyTints[part]}`}>
              <Icon name={part} size={14} />
            </span>
            <div>
              <h2 className="section-title">{storyPartTitles[part]}</h2>
              <StoryText text={text} />
            </div>
          </section>
        ))
      )}
      {entry.metrics.length > 0 && (
        <section className="metrics">
          <h2 className="section-title">Metrics</h2>
          <div className="metrics-grid">
            {entry.metrics.map((metric) => (
              <MetricTile key={metric.id} metric={metric} />
            ))}
          </div>
        </section>
      )}
    </article>
  )
}
