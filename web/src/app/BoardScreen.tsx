import { useMemo, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { dayDateOf } from '../domain/calendar'
import { LedgerError } from '../domain/errors'
import { exportEntry } from '../domain/markdownExport'
import { type Board, type Entry, knownEntryTypes, liveBoards, liveEntries } from '../domain/model'
import { applyQuery, type EntrySort, entrySorts, yearCounts } from '../domain/query'
import { boardPeriod, counted } from '../domain/story'
import { EntryCard, EntryRow } from '../ui/board/EntryCard'
import { Sidebar } from '../ui/board/Sidebar'
import { type Layout, Toolbar } from '../ui/board/Toolbar'
import { Icon } from '../ui/components/Icon'
import { BoardEditor } from '../ui/editor/BoardEditor'
import { EntryEditor } from '../ui/editor/EntryEditor'
import { EntryDetail } from '../ui/entry/EntryDetail'
import { ExportDialog } from '../ui/export/ExportDialog'
import { shortMonth } from '../ui/format'
import type { AppModel, AppState } from './appModel'
import { usePreference } from './usePreference'

type Modal =
  | { kind: 'export' }
  | { kind: 'board'; board?: Board }
  | { kind: 'entry'; entry?: Entry }
  | undefined

/** The sidebar, the tasks of one board or of all, and the selected task's story. */
export function BoardScreen(props: {
  model: AppModel
  state: AppState
  menuOpen: boolean
  onMenu: (open: boolean) => void
}) {
  const { model, state } = props
  const { boardId, entryId } = useParams()
  const navigate = useNavigate()
  const [text, setText] = useState('')
  const [kinds, setKinds] = useState<ReadonlySet<string>>(new Set())
  const [year, setYear] = useState<number>()
  const [sort, setSort] = usePreference<EntrySort>('sort', 'newest', entrySorts)
  const [layout, setLayout] = usePreference<Layout>('layout', 'grid', ['grid', 'list'])
  const [modal, setModal] = useState<Modal>()
  // Today, for new items and exports: read once when the screen mounts.
  const [today] = useState(() => dayDateOf(Date.now()))

  const boards = useMemo(() => liveBoards(state.snapshot), [state.snapshot])
  const entries = useMemo(() => liveEntries(state.snapshot), [state.snapshot])
  const board = boards.find((item) => item.id === boardId)
  const scoped = board ? entries.filter((entry) => entry.boardId === board.id) : entries
  const shown = applyQuery({ boardId: board?.id, types: kinds, year, text, sort }, entries)
  const selected = entries.find((entry) => entry.id === entryId)
  const boardName = (id: string) => boards.find((item) => item.id === id)?.name ?? ''
  const counts = useMemo(() => {
    const map = new Map<string, number>()
    for (const entry of entries) map.set(entry.boardId, (map.get(entry.boardId) ?? 0) + 1)
    return map
  }, [entries])
  // Known kinds always; a kind a newer build wrote shows once a task carries it.
  const allKinds = [...new Set([...knownEntryTypes, ...entries.map((entry) => entry.type)])]
  const base = board ? `/b/${board.id}` : ''
  const taskPath = (entry: Entry) => `${base}/t/${entry.id}`
  const listPath = base || '/'

  const run = (change: () => void) => {
    try {
      change()
    } catch (error) {
      window.alert(
        error instanceof LedgerError
          ? 'That item was deleted on another device.'
          : 'This change could not be made.',
      )
    }
  }

  const deleteBoard = (target: Board) => {
    const count = counts.get(target.id) ?? 0
    const what =
      count > 0 ? `"${target.name}" and its ${counted(count, 'task')}` : `"${target.name}"`
    if (!window.confirm(`Delete ${what}? This syncs to every device.`)) return
    run(() => model.deleteBoard(target.id))
    navigate('/')
  }

  const deleteEntry = (entry: Entry) => {
    if (!window.confirm(`Delete "${entry.name || 'Untitled'}"? This syncs to every device.`)) return
    run(() => model.deleteEntry(entry.id))
    navigate(listPath)
  }

  const loading = !state.loaded && state.sync.kind !== 'failed'
  return (
    <div className={`panes${selected ? '' : ' no-detail'}`}>
      <aside className={`pane-sidebar${props.menuOpen ? ' is-open' : ''}`}>
        <Sidebar
          boards={boards}
          counts={counts}
          total={entries.length}
          canEdit={state.canEdit}
          onNewBoard={() => setModal({ kind: 'board' })}
          onNavigate={() => props.onMenu(false)}
        />
      </aside>
      <main className="pane-main">
        <div className="board-header">
          <div className="board-header-text">
            <h1>{board ? board.name || 'Untitled board' : 'All boards'}</h1>
            <span>
              {board && `${boardPeriod(board, shortMonth)} · `}
              {counted(scoped.length, 'task')}
            </span>
          </div>
          <div className="board-header-actions">
            {state.canEdit && boards.length > 0 && (
              <button
                type="button"
                className="button button-primary"
                onClick={() => setModal({ kind: 'entry' })}
              >
                <Icon name="plus" />
                New task
              </button>
            )}
            {board && state.canEdit && (
              <>
                <button
                  type="button"
                  className="button button-icon"
                  onClick={() => setModal({ kind: 'board', board })}
                >
                  <Icon name="pencil" label="Edit board" />
                </button>
                <button
                  type="button"
                  className="button button-icon button-danger"
                  onClick={() => deleteBoard(board)}
                >
                  <Icon name="trash" label="Delete board" />
                </button>
              </>
            )}
            <button
              type="button"
              className="button"
              onClick={() => setModal({ kind: 'export' })}
              disabled={!state.loaded}
            >
              <Icon name="download" />
              Export
            </button>
          </div>
        </div>
        <Toolbar
          text={text}
          onText={setText}
          kinds={allKinds}
          selectedKinds={kinds}
          onToggleKind={(kind) => {
            const next = new Set(kinds)
            if (!next.delete(kind)) next.add(kind)
            setKinds(next)
          }}
          onAllKinds={() => setKinds(new Set())}
          years={yearCounts(scoped)}
          total={scoped.length}
          year={year}
          onYear={setYear}
          sort={sort}
          onSort={setSort}
          layout={layout}
          onLayout={setLayout}
        />
        {loading ? (
          <p className="empty">Reading your file from Drive...</p>
        ) : boardId && !board ? (
          <p className="empty">
            This board was deleted. <Link to="/">Show all boards</Link>
          </p>
        ) : shown.length === 0 ? (
          <p className="empty">{scoped.length === 0 ? 'No tasks yet.' : 'No tasks match.'}</p>
        ) : layout === 'grid' ? (
          <div className="entry-grid">
            {shown.map((entry) => (
              <EntryCard
                key={entry.id}
                entry={entry}
                to={taskPath(entry)}
                isSelected={entry.id === entryId}
                boardName={board ? undefined : boardName(entry.boardId)}
                filterYear={year}
              />
            ))}
          </div>
        ) : (
          <div className="entry-list">
            {shown.map((entry) => (
              <EntryRow
                key={entry.id}
                entry={entry}
                to={taskPath(entry)}
                isSelected={entry.id === entryId}
                boardName={board ? undefined : boardName(entry.boardId)}
              />
            ))}
          </div>
        )}
      </main>
      {selected && (
        <section className="pane-detail">
          <EntryDetail
            entry={selected}
            boardName={boardName(selected.boardId)}
            canEdit={state.canEdit}
            onEdit={() => setModal({ kind: 'entry', entry: selected })}
            onDelete={() => deleteEntry(selected)}
            onCopy={() => void navigator.clipboard.writeText(exportEntry(selected))}
            backTo={
              <Link to={listPath} className="button button-icon" title="Close">
                <Icon name="back" label="Back to the list" />
              </Link>
            }
          />
        </section>
      )}
      {modal?.kind === 'export' && (
        <ExportDialog
          boards={boards}
          entries={entries}
          board={board}
          today={today}
          onClose={() => setModal(undefined)}
        />
      )}
      {modal?.kind === 'board' && (
        <BoardEditor
          board={modal.board}
          today={today}
          onCancel={() => setModal(undefined)}
          onSave={(edited) => {
            run(() => {
              const saved = model.saveBoard(edited)
              setModal(undefined)
              navigate(`/b/${saved.id}`)
            })
          }}
        />
      )}
      {modal?.kind === 'entry' && (
        <EntryEditor
          entry={modal.entry}
          boards={boards}
          defaultBoardId={board?.id ?? selected?.boardId ?? boards[0]?.id ?? ''}
          kinds={allKinds}
          today={today}
          onCancel={() => setModal(undefined)}
          onSave={(edited) => {
            run(() => {
              const saved = model.saveEntry(edited)
              setModal(undefined)
              // Stay in the current view, unless the task moved off the board on screen.
              const moved = board !== undefined && saved.boardId !== board.id
              navigate(`${moved ? `/b/${saved.boardId}` : base}/t/${saved.id}`)
            })
          }}
        />
      )}
    </div>
  )
}
