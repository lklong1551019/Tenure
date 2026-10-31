// Google sign-in for the web, with Google Identity Services' token model. There is no refresh
// token in the browser, by Google's design: an access token lasts about an hour and lives in
// this object only, never in storage. When it runs out, the user clicks once to get another;
// Google remembers the grant, so the popup closes by itself. See docs/WEB.md for why there is
// no longer session (it would need a server holding a client secret).
import { RemoteStoreError } from '../domain/errors'
import type { AccessTokenProviding } from './driveClient'

/** Files this app created, nothing else in the Drive; no profile or email scope. */
export const driveFileScope = 'https://www.googleapis.com/auth/drive.file'

/** Refreshed this long before Google's expiry, so a request never starts with a lapsing token. */
const refreshMarginMillis = 60_000

export type AuthState =
  /** This build has no web OAuth client (VITE_GOOGLE_CLIENT_ID is missing or `temp`). */
  | { kind: 'notConfigured' }
  /** Google's script has not loaded yet. */
  | { kind: 'loading' }
  | { kind: 'signedOut' }
  | { kind: 'signedIn' }
  /** Had a token that ran out; edits stay in memory until the next sign-in. */
  | { kind: 'expired' }

export type SignInFailure = 'cancelled' | 'popupBlocked' | 'driveNotGranted' | 'failed'

export class SignInError extends Error {
  constructor(readonly failure: SignInFailure) {
    super(`sign-in: ${failure}`)
    this.name = 'SignInError'
  }
}

export function isConfigured(clientId: string | undefined): clientId is string {
  const id = clientId?.trim() ?? ''
  return id !== '' && id !== 'temp'
}

export class GoogleAuth implements AccessTokenProviding {
  private client: google.accounts.oauth2.TokenClient | undefined
  private access: { token: string; expiresAt: number } | undefined
  private pending: { resolve: () => void; reject: (error: SignInError) => void } | undefined
  private current: AuthState
  private readonly listeners = new Set<() => void>()

  constructor(
    private readonly clientId: string | undefined,
    private readonly now: () => number = Date.now,
  ) {
    this.current = isConfigured(clientId) ? { kind: 'loading' } : { kind: 'notConfigured' }
  }

  state(): AuthState {
    return this.current
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener)
    return () => this.listeners.delete(listener)
  }

  /** Waits for Google's script, then makes the token client. Safe to call more than once. */
  async load(): Promise<void> {
    if (!isConfigured(this.clientId) || this.client) return
    const oauth2 = await gisLoaded()
    this.client = oauth2.initTokenClient({
      client_id: this.clientId,
      scope: driveFileScope,
      // Consent only the first time; afterwards the popup closes by itself.
      prompt: '',
      callback: (response) => this.receive(response),
      error_callback: (error) =>
        this.settle(new SignInError(error.type === 'popup_closed' ? 'cancelled' : 'popupBlocked')),
    })
    if (this.current.kind === 'loading') this.setState({ kind: 'signedOut' })
  }

  /**
   * Opens Google's popup. Call it straight from a click handler, with nothing awaited
   * before it, or the browser blocks the popup.
   */
  signIn(): Promise<void> {
    const client = this.client
    if (!client) return Promise.reject(new SignInError('failed'))
    this.settle(new SignInError('cancelled'))
    const result = new Promise<void>((resolve, reject) => {
      this.pending = { resolve, reject }
    })
    client.requestAccessToken()
    return result
  }

  /** Revokes the grant with Google (best effort) and forgets the token. */
  signOut(): void {
    const token = this.access?.token
    this.access = undefined
    if (token) window.google?.accounts?.oauth2?.revoke(token)
    if (this.client) this.setState({ kind: 'signedOut' })
  }

  async accessToken(): Promise<string> {
    if (this.access && this.access.expiresAt > this.now() + refreshMarginMillis) {
      return this.access.token
    }
    if (this.access) {
      this.access = undefined
      this.setState({ kind: 'expired' })
    }
    throw new RemoteStoreError({ kind: 'signedOut' })
  }

  invalidateAccessToken(): void {
    if (!this.access) return
    this.access = undefined
    this.setState({ kind: 'expired' })
  }

  private receive(response: google.accounts.oauth2.TokenResponse): void {
    if (response.error || !response.access_token) {
      this.settle(new SignInError(response.error === 'access_denied' ? 'cancelled' : 'failed'))
      return
    }
    // The consent screen lets the user untick Drive access; without it nothing works.
    if (!window.google?.accounts?.oauth2?.hasGrantedAllScopes(response, driveFileScope)) {
      this.settle(new SignInError('driveNotGranted'))
      return
    }
    this.access = {
      token: response.access_token,
      expiresAt: this.now() + Number(response.expires_in) * 1000,
    }
    this.setState({ kind: 'signedIn' })
    this.settle()
  }

  private settle(error?: SignInError): void {
    const pending = this.pending
    this.pending = undefined
    if (!pending) return
    if (error) pending.reject(error)
    else pending.resolve()
  }

  private setState(state: AuthState): void {
    this.current = state
    for (const listener of this.listeners) listener()
  }
}

/** Resolves once https://accounts.google.com/gsi/client has run (index.html loads it async). */
function gisLoaded(): Promise<typeof google.accounts.oauth2> {
  const ready = () => window.google?.accounts?.oauth2
  return new Promise((resolve, reject) => {
    const found = ready()
    if (found) return resolve(found)
    const started = Date.now()
    const timer = setInterval(() => {
      const loaded = ready()
      if (loaded) {
        clearInterval(timer)
        resolve(loaded)
      } else if (Date.now() - started > 20_000) {
        clearInterval(timer)
        reject(new SignInError('failed'))
      }
    }, 100)
  })
}
