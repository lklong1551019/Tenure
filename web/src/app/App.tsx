import { useEffect, useState } from 'react'
import { Route, Routes } from 'react-router-dom'
import { Icon } from '../ui/components/Icon'
import { SignIn } from '../ui/shell/SignIn'
import { signInFailureText, syncFailureText } from '../ui/shell/messages'
import type { AppModel, AppState } from './appModel'
import { BoardScreen } from './BoardScreen'
import { useAppState } from './useAppState'
import '../ui/components/components.css'
import '../ui/shell/shell.css'

export function App({ model }: { model: AppModel }) {
  const state = useAppState(model)
  const [menuOpen, setMenuOpen] = useState(false)

  useEffect(() => model.start(), [model])

  // A closing tab with changes not yet in Drive asks first; they live only on this page.
  useEffect(() => {
    if (!state.unsaved) return
    const warn = (event: BeforeUnloadEvent) => event.preventDefault()
    window.addEventListener('beforeunload', warn)
    return () => window.removeEventListener('beforeunload', warn)
  }, [state.unsaved])

  const { auth } = state
  if (
    auth.kind === 'notConfigured' ||
    auth.kind === 'loading' ||
    (auth.kind === 'signedOut' && !state.loaded)
  ) {
    return (
      <SignIn
        state={auth.kind === 'signedOut' ? 'signedOut' : auth.kind}
        failure={state.signInFailure && signInFailureText(state.signInFailure)}
        namespace={state.namespace}
        onSignIn={model.signIn}
      />
    )
  }

  const screen = (
    <BoardScreen model={model} state={state} menuOpen={menuOpen} onMenu={setMenuOpen} />
  )
  return (
    <div className="shell">
      <header className="topbar">
        <button
          type="button"
          className="button button-quiet button-icon only-phone"
          aria-expanded={menuOpen}
          onClick={() => setMenuOpen(!menuOpen)}
        >
          <Icon name={menuOpen ? 'close' : 'menu'} label="Boards" />
        </button>
        <span className="topbar-title">
          <span className="app-mark" aria-hidden="true">
            T
          </span>
          Tenure
        </span>
        <SyncStatusText state={state} />
        <button
          type="button"
          className="button button-quiet button-icon"
          onClick={() => void model.syncNow()}
          disabled={auth.kind !== 'signedIn' || state.sync.kind === 'syncing'}
        >
          <Icon name="sync" label="Sync now" />
        </button>
        <button type="button" className="button button-quiet" onClick={model.signOut}>
          Sign out
        </button>
      </header>
      <Banners state={state} onSignIn={model.signIn} />
      <Routes>
        {['/', '/b/:boardId', '/t/:entryId', '/b/:boardId/t/:entryId'].map((path) => (
          <Route key={path} path={path} element={screen} />
        ))}
        <Route path="*" element={screen} />
      </Routes>
    </div>
  )
}

function SyncStatusText({ state }: { state: AppState }) {
  const text = (() => {
    if (state.sync.kind === 'syncing') return 'Syncing...'
    if (state.unsaved) return 'Not saved to Drive yet'
    if (state.sync.kind === 'synced') return `Saved to Drive at ${clock(state.sync.at)}`
    if (state.sync.kind === 'failed' && state.loaded) return 'Not synced'
    return ''
  })()
  return (
    <span className={`sync-status${state.unsaved ? ' is-unsaved' : ''}`} role="status">
      {text}
    </span>
  )
}

const clock = (millis: number) =>
  new Date(millis).toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' })

function Banners({ state, onSignIn }: { state: AppState; onSignIn: () => void }) {
  const banners = []
  if (state.auth.kind === 'expired') {
    banners.push(
      <div key="expired" className="banner tint-amber">
        <p>
          Your Google session ended.{' '}
          {state.unsaved
            ? 'Sign in again to save your changes; they are kept on this page.'
            : 'Sign in again to keep syncing.'}
        </p>
        <button type="button" className="button button-primary" onClick={onSignIn}>
          Sign in again
        </button>
      </div>,
    )
  } else if (state.sync.kind === 'failed') {
    banners.push(
      <div key="sync" className="banner tint-red">
        <p>{syncFailureText(state.sync.error)}</p>
      </div>,
    )
  }
  if (state.namespace) {
    banners.push(
      <div key="namespace" className="banner tint-violet">
        <p>
          {state.namespace === 'demo'
            ? 'Demo data: nothing here leaves this page.'
            : `Test data: the Mac app's Debug file (${state.namespace}), not your real data.`}
        </p>
      </div>,
    )
  }
  return <>{banners}</>
}
