import { useEffect, useRef, useState } from 'react'
import type { YearCount } from '../../domain/query'
import { Icon } from '../components/Icon'
import './board.css'

/**
 * The year menu at the head of the filter row: "All years" or one year, each with how many
 * tasks fall in it. Tinted while a year is chosen, like a kind chip that is on. The web twin
 * of `YearFilterChip` on the Mac.
 */
export function YearFilterChip(props: {
  years: readonly YearCount[]
  /** Tasks in every year, for the "All years" row. */
  total: number
  year: number | undefined
  onYear: (year: number | undefined) => void
}) {
  const [isOpen, setOpen] = useState(false)
  const root = useRef<HTMLDivElement>(null)

  // Closes on a click elsewhere or Escape, like the Mac's popover.
  useEffect(() => {
    if (!isOpen) return
    const close = (event: Event) => {
      if (
        event instanceof KeyboardEvent
          ? event.key === 'Escape'
          : !root.current?.contains(event.target as Node)
      ) {
        setOpen(false)
      }
    }
    document.addEventListener('pointerdown', close)
    document.addEventListener('keydown', close)
    return () => {
      document.removeEventListener('pointerdown', close)
      document.removeEventListener('keydown', close)
    }
  }, [isOpen])

  const choose = (year: number | undefined) => {
    props.onYear(year)
    setOpen(false)
  }

  const row = (title: string, count: number, isOn: boolean, year: number | undefined) => (
    <button
      type="button"
      role="menuitemradio"
      aria-checked={isOn}
      className={`year-menu-row${isOn ? ' is-on' : ''}`}
      onClick={() => choose(year)}
    >
      <span>{title}</span>
      <span className="year-menu-count">{count}</span>
    </button>
  )

  return (
    <div className="year-filter" ref={root}>
      <button
        type="button"
        className={`year-chip${props.year === undefined ? '' : ' is-on'}`}
        aria-haspopup="menu"
        aria-expanded={isOpen}
        disabled={props.years.length === 0}
        title="Show one year's tasks"
        onClick={() => setOpen(!isOpen)}
      >
        <Icon name="calendar" size={14} />
        {props.year ?? 'All years'}
        <Icon name="chevron" size={12} />
      </button>
      {isOpen && (
        <div className="year-menu" role="menu" aria-label="Year">
          {row('All years', props.total, props.year === undefined, undefined)}
          <hr />
          {props.years.map((item) => (
            <div key={item.year}>
              {row(String(item.year), item.count, props.year === item.year, item.year)}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
