import { useState } from 'react'
import type { DayDate } from '../../domain/calendar'
import { yearMonth } from '../../domain/calendar'
import type { Board } from '../../domain/model'
import { Dialog } from '../components/Dialog'
import { boardDraft, boardFromDraft, boardProblem } from './drafts'
import './editor.css'

/** New board or edit one: name, and the months it ran. */
export function BoardEditor(props: {
  board?: Board
  today: DayDate
  onCancel: () => void
  onSave: (board: Board) => void
}) {
  const [draft, setDraft] = useState(() =>
    boardDraft(props.board, yearMonth(props.today.year, props.today.month)),
  )
  const problem = boardProblem(draft)
  const update = (change: Partial<typeof draft>) => setDraft({ ...draft, ...change })
  return (
    <Dialog title={props.board ? 'Edit board' : 'New board'} onClose={props.onCancel}>
      <form
        className="editor"
        onSubmit={(event) => {
          event.preventDefault()
          if (!problem) props.onSave(boardFromDraft(draft, Date.now()))
        }}
      >
        <label className="editor-field">
          <span>Name</span>
          <input
            className="field"
            value={draft.name}
            placeholder="Company A"
            autoFocus
            onChange={(event) => update({ name: event.target.value })}
          />
        </label>
        <div className="editor-row">
          <label className="editor-field">
            <span>Started</span>
            <input
              type="month"
              className="field"
              value={draft.start}
              onChange={(event) => update({ start: event.target.value })}
            />
          </label>
          <label className="editor-field">
            <span>Ended</span>
            <input
              type="month"
              className="field"
              value={draft.end}
              disabled={draft.isCurrent}
              onChange={(event) => update({ end: event.target.value })}
            />
          </label>
        </div>
        <label className="check">
          <input
            type="checkbox"
            checked={draft.isCurrent}
            onChange={(event) => update({ isCurrent: event.target.checked })}
          />
          I still work here
        </label>
        {problem && draft.name !== '' && <p className="editor-problem">{problem}</p>}
        <div className="dialog-actions">
          <button type="button" className="button" onClick={props.onCancel}>
            Cancel
          </button>
          <button type="submit" className="button button-primary" disabled={problem !== undefined}>
            {props.board ? 'Save' : 'Add board'}
          </button>
        </div>
      </form>
    </Dialog>
  )
}
