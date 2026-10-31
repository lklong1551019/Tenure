// What the screens see and do: the ledger, sign-in, and sync, wired together. The
// counterpart of App/Sources/AppModel.swift plus SyncScheduler.swift on the Mac.
//
// Sync runs after sign-in, 2 s after the last edit, when the tab is hidden, every 5 minutes
// while it is visible, and on "Sync now"; one round at a time. Edits are allowed only after
// the first round has read the file, and stop while the file is refused (newer, corrupt, or
// missing), so the web never writes over something it could not read.
import type { SyncErrorKind } from '../domain/errors'
import { RemoteStoreError, SyncError } from '../domain/errors'
import { fingerprint } from '../domain/fingerprint'
import type { LedgerStore } from '../domain/ledgerStore'
import type { Board, Entry, LedgerSnapshot, Uuid } from '../domain/model'
import type { SyncLedger } from '../domain/sync/syncLedger'
import type { AuthState } from '../data/googleAuth'
import { SignInError, type SignInFailure } from '../data/googleAuth'

/** What the app needs from sign-in: `GoogleAuth`, or the demo's stand-in. */
export interface AuthPort {
  state(): AuthState
  subscribe(listener: () => void): () => void
  load(): Promise<void>
  signIn(): Promise<void>
  signOut(): void
}

export type SyncStatus =
  | { kind: 'idle' }
  | { kind: 'syncing' }
  | { kind: 'synced'; at: number }
  | { kind: 'failed'; error: SyncErrorKind; at: number }

export interface AppState {
  readonly auth: AuthState
  readonly sync: SyncStatus
  readonly snapshot: LedgerSnapshot
  /** The file was read at least once since sign-in. */
  readonly loaded: boolean
  /** Local changes not yet in Drive. */
  readonly unsaved: boolean
  /** Edits are accepted: loaded, and the file is not refused. */
  readonly canEdit: boolean
  readonly signInFailure?: SignInFailure
  /** "dev" when the page reads the Mac's Debug data (`?ns=dev`). */
  readonly namespace: string
}

export interface AppDependencies {
  readonly auth: AuthPort
  readonly store: LedgerStore
  readonly sync: SyncLedger
  readonly namespace: string
  readonly now?: () => number
}

const editDelayMillis = 2_000
const periodicMillis = 5 * 60_000

/** Errors after which nothing may be written until a round reads the file again. */
const refused = new Set<SyncErrorKind['kind']>([
  'unsupportedRemote',
  'corruptRemote',
  'noRemoteFile',
])

export class AppModel {
  private readonly auth: AuthPort
  private readonly store: LedgerStore
  private readonly sync: SyncLedger
  private readonly now: () => number
  private status: SyncStatus = { kind: 'idle' }
  private loaded = false
  private signInFailure: SignInFailure | undefined
  private running: Promise<void> | undefined
  private again = false
  private editTimer: ReturnType<typeof setTimeout> | undefined
  private periodicTimer: ReturnType<typeof setInterval> | undefined
  private state: AppState
  private readonly listeners = new Set<() => void>()

  constructor(private readonly dependencies: AppDependencies) {
    this.auth = dependencies.auth
    this.store = dependencies.store
    this.sync = dependencies.sync
    this.now = dependencies.now ?? Date.now
    this.state = this.makeState()
    this.auth.subscribe(() => this.publish())
    this.store.subscribe(() => this.publish())
  }

  // MARK: Observing

  getState = (): AppState => this.state

  subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener)
    return () => this.listeners.delete(listener)
  }

  // MARK: Lifecycle

  /** Loads Google's sign-in and starts the timers. Returns a function that stops them. */
  start(): () => void {
    void this.auth.load().catch(() => {
      this.signInFailure = 'failed'
      this.publish()
    })
    const onVisibility = () => {
      if (document.visibilityState === 'hidden' && this.state.unsaved) void this.syncNow()
    }
    document.addEventListener('visibilitychange', onVisibility)
    this.periodicTimer = setInterval(() => {
      if (document.visibilityState === 'visible') void this.syncNow()
    }, periodicMillis)
    return () => {
      document.removeEventListener('visibilitychange', onVisibility)
      clearInterval(this.periodicTimer)
      clearTimeout(this.editTimer)
    }
  }

  /** From a click: Google's popup, then a sync round. */
  signIn = (): void => {
    this.signInFailure = undefined
    this.auth
      .signIn()
      .then(() => this.syncNow())
      .catch((error: unknown) => {
        this.signInFailure = error instanceof SignInError ? error.failure : 'failed'
        this.publish()
      })
    this.publish()
  }

  /** Forgets the token and every piece of data on this page. */
  signOut = (): void => {
    if (
      this.state.unsaved &&
      !window.confirm('Some changes are not in Drive yet. Sign out and lose them?')
    ) {
      return
    }
    clearTimeout(this.editTimer)
    this.auth.signOut()
    this.sync.clear()
    this.loaded = false
    this.status = { kind: 'idle' }
    this.store.reset()
  }

  /** One round now, or right after the running one. */
  syncNow = (): Promise<void> => {
    if (this.running) {
      this.again = true
      return this.running
    }
    this.running = this.round().finally(() => {
      this.running = undefined
      if (this.again) {
        this.again = false
        void this.syncNow()
      }
    })
    return this.running
  }

  // MARK: Editing. Each throws LedgerError when the item is gone; the screens show it.

  saveBoard = (board: Board): Board => this.edit(() => this.store.saveBoard(board))

  deleteBoard = (id: Uuid): void => this.edit(() => this.store.deleteBoard(id))

  saveEntry = (entry: Entry): Entry => this.edit(() => this.store.saveEntry(entry))

  deleteEntry = (id: Uuid): void => this.edit(() => this.store.deleteEntry(id))

  // MARK: Private

  private edit<Value>(change: () => Value): Value {
    if (!this.state.canEdit) throw new Error('editing is off until the file is read')
    const value = change()
    clearTimeout(this.editTimer)
    this.editTimer = setTimeout(() => void this.syncNow(), editDelayMillis)
    return value
  }

  private async round(): Promise<void> {
    if (this.auth.state().kind !== 'signedIn') return
    this.status = { kind: 'syncing' }
    this.publish()
    try {
      await this.sync.run(this.store)
      this.loaded = true
      this.status = { kind: 'synced', at: this.now() }
    } catch (error) {
      this.status = { kind: 'failed', error: syncErrorKind(error), at: this.now() }
    }
    this.publish()
  }

  private makeState(): AppState {
    const snapshot = this.store.snapshot()
    const record = this.sync.lastRecord()
    const unsaved = record !== undefined && fingerprint(snapshot) !== record.fingerprint
    const blocked = this.status.kind === 'failed' && refused.has(this.status.error.kind)
    return {
      auth: this.auth.state(),
      sync: this.status,
      snapshot,
      loaded: this.loaded,
      unsaved,
      canEdit: this.loaded && !blocked,
      signInFailure: this.signInFailure,
      namespace: this.dependencies.namespace,
    }
  }

  private publish(): void {
    this.state = this.makeState()
    for (const listener of this.listeners) listener()
  }
}

function syncErrorKind(error: unknown): SyncErrorKind {
  if (error instanceof SyncError) return error.reason
  if (error instanceof RemoteStoreError) return { kind: 'remote', error: error.reason }
  return { kind: 'remote', error: { kind: 'server', status: 0 } }
}
