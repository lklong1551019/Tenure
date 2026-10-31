import type { Tint } from '../format'
import './components.css'

/** Toggleable capsule: a dot in the kind's color, tinted in that color while on. */
export function FilterChip(props: {
  text: string
  tint: Tint
  isOn: boolean
  onToggle: () => void
}) {
  return (
    <button
      type="button"
      className={`filter-chip tint-${props.tint}`}
      aria-pressed={props.isOn}
      onClick={props.onToggle}
    >
      {props.text}
    </button>
  )
}
