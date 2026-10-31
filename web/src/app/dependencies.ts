// The composition root: the one place that picks concrete implementations for the ports.
import { LedgerStore } from '../domain/ledgerStore'
import { SyncLedger } from '../domain/sync/syncLedger'
import { DriveClient } from '../data/driveClient'
import { GoogleAuth } from '../data/googleAuth'
import { ledgerFileCodec } from '../data/ledgerFileCodec'
import { AppModel } from './appModel'

/**
 * `?ns=dev` reads and writes the data of the Mac app's Debug builds instead of the real
 * file, for trying the web on test data. Anything else is the real file.
 */
export function namespaceFrom(search: string): string {
  return new URLSearchParams(search).get('ns') === 'dev' ? 'dev' : ''
}

export async function makeAppModel(): Promise<AppModel> {
  if (import.meta.env.DEV && new URLSearchParams(window.location.search).has('demo')) {
    const { makeDemoAppModel } = await import('./demo')
    return makeDemoAppModel()
  }
  const namespace = namespaceFrom(window.location.search)
  const auth = new GoogleAuth(import.meta.env.VITE_GOOGLE_CLIENT_ID)
  const store = new LedgerStore()
  const sync = new SyncLedger(new DriveClient(auth, namespace), ledgerFileCodec)
  return new AppModel({ auth, store, sync, namespace })
}
