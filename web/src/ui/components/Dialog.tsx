import { type ReactNode, useEffect, useRef } from 'react'
import './components.css'

/** A modal on the native <dialog>: focus trap, Escape, and backdrop come with it. */
export function Dialog(props: { title: string; onClose: () => void; children: ReactNode }) {
  const ref = useRef<HTMLDialogElement>(null)
  useEffect(() => {
    const dialog = ref.current
    if (dialog && !dialog.open) dialog.showModal()
    return () => dialog?.close()
  }, [])
  return (
    <dialog
      ref={ref}
      className="dialog"
      aria-label={props.title}
      onCancel={(event) => {
        event.preventDefault()
        props.onClose()
      }}
    >
      <div className="dialog-body">
        <h2 className="dialog-title">{props.title}</h2>
        {props.children}
      </div>
    </dialog>
  )
}
