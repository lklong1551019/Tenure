import { useState } from 'react'
import type { DayDate } from '../../domain/calendar'
import { type Board, type Entry, entryTypeTitle } from '../../domain/model'
import { storyPartTitles, storyParts } from '../../domain/story'
import { Dialog } from '../components/Dialog'
import { Icon } from '../components/Icon'
import {
  type EntryDraft,
  entryDraft,
  entryFromDraft,
  entryProblem,
  type MetricDraft,
  metricDraft,
} from './drafts'
import './editor.css'

const storyHints = {
  problem: 'What was wrong, and for whom?',
  why: 'Why it mattered then.',
  solution: 'What you did. **bold**, *italic*, `code`, and [links](https://...) work.',
  impact: 'What changed, in numbers if you have them.',
  difficulties: 'What got in the way, and how you got past it.',
} as const

/** New task or edit one: the facts, the five-part story, and the metrics. */
export function EntryEditor(props: {
  entry?: Entry
  boards: readonly Board[]
  defaultBoardId: string
  kinds: readonly string[]
  today: DayDate
  onCancel: () => void
  onSave: (entry: Entry) => void
}) {
  const [draft, setDraft] = useState(() =>
    entryDraft(props.entry, props.defaultBoardId, props.today),
  )
  const problem = entryProblem(draft)
  const update = (change: Partial<EntryDraft>) => setDraft({ ...draft, ...change })
  const updateMetric = (id: string, change: Partial<MetricDraft>) =>
    update({ metrics: draft.metrics.map((m) => (m.id === id ? { ...m, ...change } : m)) })

  return (
    <Dialog title={props.entry ? 'Edit task' : 'New task'} onClose={props.onCancel}>
      <form
        className="editor editor-wide"
        onSubmit={(event) => {
          event.preventDefault()
          if (!problem) props.onSave(entryFromDraft(draft, Date.now()))
        }}
      >
        <label className="editor-field">
          <span>Name</span>
          <input
            className="field"
            value={draft.name}
            autoFocus
            placeholder="Halve cold start on Android"
            onChange={(event) => update({ name: event.target.value })}
          />
        </label>
        <div className="editor-row">
          <label className="editor-field">
            <span>Board</span>
            <select
              className="field"
              value={draft.boardId}
              onChange={(event) => update({ boardId: event.target.value })}
            >
              {props.boards.map((board) => (
                <option key={board.id} value={board.id}>
                  {board.name || 'Untitled board'}
                </option>
              ))}
            </select>
          </label>
          <label className="editor-field">
            <span>Kind</span>
            <select
              className="field"
              value={draft.type}
              onChange={(event) => update({ type: event.target.value })}
            >
              {props.kinds.map((kind) => (
                <option key={kind} value={kind}>
                  {entryTypeTitle(kind)}
                </option>
              ))}
            </select>
          </label>
        </div>
        <div className="editor-row">
          <label className="editor-field">
            <span>Date</span>
            <input
              type="date"
              className="field"
              value={draft.date}
              onChange={(event) => update({ date: event.target.value })}
            />
          </label>
          <label className="editor-field">
            <span>End date</span>
            <input
              type="date"
              className="field"
              value={draft.endDate}
              disabled={!draft.hasEndDate}
              onChange={(event) => update({ endDate: event.target.value })}
            />
          </label>
        </div>
        <label className="check">
          <input
            type="checkbox"
            checked={draft.hasEndDate}
            onChange={(event) => update({ hasEndDate: event.target.checked })}
          />
          Spanned several days
        </label>
        <label className="editor-field">
          <span>Link</span>
          <input
            className="field"
            value={draft.link}
            inputMode="url"
            placeholder="Ticket or document"
            onChange={(event) => update({ link: event.target.value })}
          />
        </label>
        <label className="editor-field">
          <span>Tags</span>
          <input
            className="field"
            value={draft.tags}
            placeholder="performance, android"
            onChange={(event) => update({ tags: event.target.value })}
          />
        </label>
        {storyParts.map((part) => (
          <label key={part} className="editor-field">
            <span>{storyPartTitles[part]}</span>
            <textarea
              className="field"
              rows={3}
              value={draft[part]}
              placeholder={storyHints[part]}
              onChange={(event) => update({ [part]: event.target.value })}
            />
          </label>
        ))}
        <fieldset className="editor-metrics">
          <legend className="section-title">Metrics</legend>
          {draft.metrics.map((metric) => (
            <div key={metric.id} className="editor-metric">
              <input
                className="field"
                aria-label="Label"
                placeholder="Cold start p50"
                value={metric.label}
                onChange={(event) => updateMetric(metric.id, { label: event.target.value })}
              />
              <input
                className="field"
                aria-label="Before"
                placeholder="Before"
                value={metric.before}
                onChange={(event) => updateMetric(metric.id, { before: event.target.value })}
              />
              <input
                className="field"
                aria-label="After"
                placeholder="After"
                value={metric.after}
                onChange={(event) => updateMetric(metric.id, { after: event.target.value })}
              />
              <input
                className="field"
                aria-label="Unit"
                placeholder="Unit"
                value={metric.unit}
                onChange={(event) => updateMetric(metric.id, { unit: event.target.value })}
              />
              <input
                className="field editor-metric-note"
                aria-label="How it was measured"
                placeholder="How it was measured"
                value={metric.note}
                onChange={(event) => updateMetric(metric.id, { note: event.target.value })}
              />
              <button
                type="button"
                className="button button-quiet button-icon"
                onClick={() => update({ metrics: draft.metrics.filter((m) => m.id !== metric.id) })}
              >
                <Icon name="close" label="Remove metric" />
              </button>
            </div>
          ))}
          <button
            type="button"
            className="button"
            onClick={() => update({ metrics: [...draft.metrics, metricDraft()] })}
          >
            <Icon name="plus" />
            Add metric
          </button>
        </fieldset>
        {problem && draft.name !== '' && <p className="editor-problem">{problem}</p>}
        <div className="dialog-actions editor-actions">
          <button type="button" className="button" onClick={props.onCancel}>
            Cancel
          </button>
          <button type="submit" className="button button-primary" disabled={problem !== undefined}>
            {props.entry ? 'Save' : 'Add task'}
          </button>
        </div>
      </form>
    </Dialog>
  )
}
