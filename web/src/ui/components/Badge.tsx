import type { Tint } from '../format'
import './components.css'

/** Small rounded label, for a task's kind and for status. */
export function Badge({ text, tint }: { text: string; tint: Tint }) {
  return <span className={`badge tint-${tint}`}>{text}</span>
}
