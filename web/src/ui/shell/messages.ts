// The words for each failure, in one place, so every screen says the same thing.
import type { SyncErrorKind } from '../../domain/errors'

export type SignInFailureText = string

export function signInFailureText(
  failure: 'cancelled' | 'popupBlocked' | 'driveNotGranted' | 'failed',
): string {
  switch (failure) {
    case 'cancelled':
      return 'Sign-in was closed before it finished.'
    case 'popupBlocked':
      return 'The browser blocked the Google sign-in window. Allow pop-ups for this page and try again.'
    case 'driveNotGranted':
      return 'Tenure needs access to the files it created in your Drive. Sign in again and leave that box ticked.'
    case 'failed':
      return "Couldn't reach Google sign-in. Check the connection and try again."
  }
}

/** What went wrong in a sync round, and whether the page can still save. */
export function syncFailureText(error: SyncErrorKind): string {
  switch (error.kind) {
    case 'unsupportedRemote':
      return `The file in Drive was written by a newer Tenure (format ${error.version}). Update the Mac app; this page won't change it.`
    case 'corruptRemote':
      return "The file in Drive can't be read. Nothing was changed; open it in the Mac app to check it."
    case 'noRemoteFile':
      return 'No Tenure file in this Drive yet. Turn on sync in the Mac app first, then reload.'
    case 'busy':
      return 'Another device kept saving at the same time. Trying again shortly.'
    case 'remote':
      switch (error.error.kind) {
        case 'signedOut':
          return 'Your Google session ended. Sign in again to save; your changes are kept on this page.'
        case 'offline':
          return 'Offline. Changes stay on this page and are saved when the connection is back.'
        case 'rateLimited':
          return 'Google Drive asked to slow down. Trying again shortly.'
        case 'notFound':
          return 'The Tenure file in Drive was moved to the trash or deleted.'
        case 'server':
          return `Google Drive answered with an error${error.error.status ? ` (${error.error.status})` : ''}. Trying again shortly.`
      }
  }
}
