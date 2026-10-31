// The part of Google Identity Services (https://accounts.google.com/gsi/client) this app uses:
// the OAuth 2.0 token model. Reference:
// https://developers.google.com/identity/oauth2/web/reference/js-reference

declare namespace google.accounts.oauth2 {
  interface TokenResponse {
    access_token: string
    /** Seconds. */
    expires_in: number
    scope: string
    error?: string
    error_description?: string
  }

  interface ClientConfigError {
    type: 'popup_failed_to_open' | 'popup_closed' | 'unknown'
    message?: string
  }

  interface TokenClientConfig {
    client_id: string
    scope: string
    prompt?: '' | 'none' | 'consent' | 'select_account'
    callback: (response: TokenResponse) => void
    error_callback?: (error: ClientConfigError) => void
  }

  interface TokenClient {
    requestAccessToken(overrides?: { prompt?: TokenClientConfig['prompt'] }): void
  }

  function initTokenClient(config: TokenClientConfig): TokenClient
  function hasGrantedAllScopes(response: TokenResponse, scope: string): boolean
  function revoke(accessToken: string, done?: () => void): void
}

interface Window {
  google?: { accounts?: { oauth2?: typeof google.accounts.oauth2 } }
}
