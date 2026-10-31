import { useState } from 'react'
import type { DayDate } from '../../domain/calendar'
import {
  exportAll,
  exportBoard,
  exportYear,
  exportYears,
  fileName,
  type MarkdownOptions,
} from '../../domain/markdownExport'
import type { Board, Entry } from '../../domain/model'
import { Dialog } from '../components/Dialog'
import { Icon } from '../components/Icon'

type Scope = 'board' | 'year' | 'all'

/** Markdown for a CV or a review: this board, one year, or everything. */
export function ExportDialog(props: {
  boards: readonly Board[]
  entries: readonly Entry[]
  /** The board on screen, if any: the default scope. */
  board?: Board
  today: DayDate
  onClose: () => void
}) {
  const years = exportYears(
    props.entries.filter((e) => props.boards.some((b) => b.id === e.boardId)),
  )
  const [scope, setScope] = useState<Scope>(props.board ? 'board' : 'all')
  const [year, setYear] = useState(years[0] ?? props.today.year)
  const [options, setOptions] = useState<MarkdownOptions>({
    story: true,
    metrics: true,
    linksAndTags: true,
  })
  const [copied, setCopied] = useState(false)

  const { title, markdown } = (() => {
    if (scope === 'board' && props.board) {
      return {
        title: props.board.name,
        markdown: exportBoard(props.board, props.entries, props.today, options),
      }
    }
    if (scope === 'year') {
      const boardId = props.board?.id
      const name = props.board ? `${props.board.name} ${year}` : `Tenure ${year}`
      return {
        title: name,
        markdown: exportYear(year, props.boards, props.entries, props.today, options, boardId),
      }
    }
    return {
      title: 'Tenure',
      markdown: exportAll(props.boards, props.entries, props.today, options),
    }
  })()

  const download = () => {
    const url = URL.createObjectURL(new Blob([markdown], { type: 'text/markdown;charset=utf-8' }))
    const anchor = document.createElement('a')
    anchor.href = url
    anchor.download = `${fileName(title)}.md`
    anchor.click()
    URL.revokeObjectURL(url)
  }

  const copy = async () => {
    await navigator.clipboard.writeText(markdown)
    setCopied(true)
  }

  const option = (key: keyof MarkdownOptions, label: string) => (
    <label className="check">
      <input
        type="checkbox"
        checked={options[key]}
        onChange={(event) => setOptions({ ...options, [key]: event.target.checked })}
      />
      {label}
    </label>
  )

  return (
    <Dialog title="Export as Markdown" onClose={props.onClose}>
      <fieldset className="choice">
        <legend className="section-title">What</legend>
        {props.board && (
          <label className="check">
            <input type="radio" checked={scope === 'board'} onChange={() => setScope('board')} />
            This board
          </label>
        )}
        <label className="check">
          <input type="radio" checked={scope === 'year'} onChange={() => setScope('year')} />
          One year{props.board ? ' of this board' : ''}
          {scope === 'year' && (
            <select
              className="field inline-field"
              value={year}
              onChange={(e) => setYear(Number(e.target.value))}
            >
              {years.map((value) => (
                <option key={value}>{value}</option>
              ))}
            </select>
          )}
        </label>
        <label className="check">
          <input type="radio" checked={scope === 'all'} onChange={() => setScope('all')} />
          Every board
        </label>
      </fieldset>
      <fieldset className="choice">
        <legend className="section-title">Include</legend>
        {option('story', 'Story')}
        {option('metrics', 'Metrics')}
        {option('linksAndTags', 'Links and tags')}
      </fieldset>
      <textarea
        className="field export-preview"
        readOnly
        value={markdown}
        rows={10}
        aria-label="Preview"
      />
      <div className="dialog-actions">
        <button type="button" className="button" onClick={props.onClose}>
          Close
        </button>
        <button type="button" className="button" onClick={copy}>
          <Icon name="copy" />
          {copied ? 'Copied' : 'Copy'}
        </button>
        <button type="button" className="button button-primary" onClick={download}>
          <Icon name="download" />
          Download .md
        </button>
      </div>
    </Dialog>
  )
}
