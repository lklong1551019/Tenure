import { NavLink } from 'react-router-dom'
import type { Board } from '../../domain/model'
import { boardPeriod, counted } from '../../domain/story'
import { Icon } from '../components/Icon'
import { shortMonth } from '../format'
import './board.css'

/** Every board, newest first, with "All boards" on top. */
export function Sidebar(props: {
  boards: readonly Board[]
  counts: ReadonlyMap<string, number>
  total: number
  canEdit: boolean
  onNewBoard: () => void
  onNavigate?: () => void
}) {
  const link = ({ isActive }: { isActive: boolean }) =>
    `sidebar-item${isActive ? ' is-active' : ''}`
  return (
    <nav className="sidebar" aria-label="Boards">
      <div className="sidebar-heading">
        <h2 className="section-title">Boards</h2>
        {props.canEdit && (
          <button
            type="button"
            className="button button-quiet button-icon"
            onClick={props.onNewBoard}
          >
            <Icon name="plus" label="New board" />
          </button>
        )}
      </div>
      <NavLink to="/" end className={link} onClick={props.onNavigate}>
        <span className="sidebar-name">All boards</span>
        <span className="sidebar-meta">{counted(props.total, 'task')}</span>
      </NavLink>
      {props.boards.map((board) => (
        <NavLink key={board.id} to={`/b/${board.id}`} className={link} onClick={props.onNavigate}>
          <span className="sidebar-name">
            <Icon name="building" size={14} />
            {board.name || 'Untitled board'}
          </span>
          <span className="sidebar-meta">
            {boardPeriod(board, shortMonth)} · {props.counts.get(board.id) ?? 0}
          </span>
        </NavLink>
      ))}
    </nav>
  )
}
