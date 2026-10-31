// Port of Packages/Data/DriveSync/Sources/DriveClient.swift, reading and replacing only. The
// data file is found by its `appProperties` marker, never by name, so a renamed or moved file
// is still found and a same-named file the user made is ignored. The web never creates the
// file or its folder and never pins a revision (see docs/WEB.md).
import { RemoteStoreError } from '../domain/errors'
import type { RemoteRevision, RemoteStorePort } from '../domain/ports'
import { check, HttpTransport } from './httpTransport'

const api = 'https://www.googleapis.com/drive/v3/'
const uploadApi = 'https://www.googleapis.com/upload/drive/v3/'
export const roleKey = 'tnRole'

/** Gives Drive requests an access token. */
export interface AccessTokenProviding {
  /** Throws `RemoteStoreError` 'signedOut' when there is no usable token. */
  accessToken(): Promise<string>
  /** After a 401: the token is no longer accepted. */
  invalidateAccessToken(): void
}

interface DriveFile {
  id: string
  headRevisionId?: string
}

export class DriveClient implements RemoteStorePort {
  /** The data file found by the last `head()`, so the calls of one round share it. */
  private fileId: string | undefined

  /**
   * `namespace` is empty for the real data; "dev" reads the file Debug builds of the Mac app
   * write (marker `ledger-dev`), so the web can be tried on test data first.
   */
  constructor(
    private readonly tokens: AccessTokenProviding,
    private readonly namespace = '',
    private readonly transport = new HttpTransport(),
  ) {}

  marker(role: string): string {
    return this.namespace === '' ? role : `${role}-${this.namespace}`
  }

  async head(): Promise<RemoteRevision | undefined> {
    const file = await this.find('ledger')
    this.fileId = file?.id
    return file && (file.headRevisionId ?? '')
  }

  async download(revision: RemoteRevision): Promise<Uint8Array> {
    const id = await this.existingFileId()
    const url = `${api}files/${enc(id)}/revisions/${enc(revision)}?alt=media`
    return this.authorized(url, { method: 'GET' })
  }

  async upload(data: string): Promise<RemoteRevision> {
    const id = await this.existingFileId()
    const url = `${uploadApi}files/${enc(id)}?uploadType=media&fields=id,headRevisionId`
    const file = json<DriveFile>(
      await this.authorized(url, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: data,
      }),
    )
    if (!file.headRevisionId) throw new RemoteStoreError({ kind: 'server', status: 0 })
    return file.headRevisionId
  }

  async revisionsAfter(revision: RemoteRevision): Promise<RemoteRevision[]> {
    const id = await this.existingFileId()
    const all: string[] = []
    let pageToken: string | undefined
    do {
      const query = new URLSearchParams({ fields: 'nextPageToken,revisions(id)', pageSize: '200' })
      if (pageToken) query.set('pageToken', pageToken)
      const page = json<{ revisions?: { id: string }[]; nextPageToken?: string }>(
        await this.authorized(`${api}files/${enc(id)}/revisions?${query}`, { method: 'GET' }),
      )
      all.push(...(page.revisions ?? []).map((item) => item.id))
      pageToken = page.nextPageToken
    } while (pageToken)
    // Drive lists oldest first. A base Drive already pruned cannot be placed; nothing is
    // reported, and the next round's head check catches up.
    const index = all.indexOf(revision)
    return index === -1 ? [] : all.slice(index + 1)
  }

  private async existingFileId(): Promise<string> {
    this.fileId ??= (await this.find('ledger'))?.id
    if (!this.fileId) throw new RemoteStoreError({ kind: 'notFound' })
    return this.fileId
  }

  /**
   * The oldest match wins, as on the Mac. Owned by the signed-in account: a file shared into
   * it never stands in for the ledger.
   */
  private async find(role: string): Promise<DriveFile | undefined> {
    const q = `appProperties has { key='${roleKey}' and value='${this.marker(role)}' } and 'me' in owners and trashed = false`
    const query = new URLSearchParams({
      q,
      spaces: 'drive',
      orderBy: 'createdTime',
      pageSize: '10',
      fields: 'files(id,headRevisionId)',
    })
    const list = json<{ files?: DriveFile[] }>(
      await this.authorized(`${api}files?${query}`, { method: 'GET' }),
    )
    return list.files?.[0]
  }

  /**
   * Adds the bearer token (a header, never the URL). A 401 gets one retry with a fresh token,
   * since the cached one may have been revoked or expired early.
   */
  private async authorized(url: string, init: RequestInit): Promise<Uint8Array> {
    for (let retried = false; ; retried = true) {
      const token = await this.tokens.accessToken()
      const headers = {
        ...(init.headers as Record<string, string>),
        Authorization: `Bearer ${token}`,
      }
      const response = await this.transport.send(url, { ...init, headers })
      if (response.status === 401 && !retried) {
        this.tokens.invalidateAccessToken()
        continue
      }
      check(response)
      return response.body
    }
  }
}

const enc = encodeURIComponent

function json<Value>(body: Uint8Array): Value {
  try {
    return JSON.parse(new TextDecoder().decode(body)) as Value
  } catch {
    throw new RemoteStoreError({ kind: 'server', status: 0 })
  }
}
