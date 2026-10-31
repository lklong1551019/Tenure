import { describe, expect, it } from 'vitest'
import { RemoteStoreError } from '../domain/errors'
import { DriveClient } from './driveClient'
import { HttpTransport, type HttpResponse } from './httpTransport'

interface Call {
  url: string
  method: string
  authorization?: string
  body?: string
}

/** A Drive that answers from a script, recording what it was asked. */
function drive(answers: ((call: Call) => HttpResponse | undefined)[]) {
  const calls: Call[] = []
  const transport = new HttpTransport(
    async (url, init) => {
      const headers = (init.headers ?? {}) as Record<string, string>
      const call = {
        url,
        method: init.method ?? 'GET',
        authorization: headers.Authorization,
        body: typeof init.body === 'string' ? init.body : undefined,
      }
      calls.push(call)
      for (const answer of answers) {
        const response = answer(call)
        if (response) return response
      }
      throw new TypeError('offline')
    },
    async () => {},
  )
  let tokens = 0
  let invalidated = 0
  const provider = {
    accessToken: async () => `token-${++tokens}`,
    invalidateAccessToken: () => void invalidated++,
  }
  return { calls, transport, provider, invalidated: () => invalidated }
}

const ok = (value: unknown, status = 200): HttpResponse => ({
  status,
  body: new TextEncoder().encode(JSON.stringify(value)),
})

const listing = (call: Call) =>
  call.url.includes('/drive/v3/files?')
    ? ok({ files: [{ id: 'f1', headRevisionId: 'r2' }] })
    : undefined

describe('DriveClient', () => {
  it('finds the file by its marker, owned by the user, never by name', async () => {
    const fake = drive([listing])
    const client = new DriveClient(fake.provider, '', fake.transport)
    expect(await client.head()).toBe('r2')
    const query = new URL(fake.calls[0]!.url).searchParams
    expect(query.get('q')).toBe(
      "appProperties has { key='tnRole' and value='ledger' } and 'me' in owners and trashed = false",
    )
    expect(query.get('orderBy')).toBe('createdTime')
    expect(fake.calls[0]!.authorization).toBe('Bearer token-1')
    expect(fake.calls[0]!.url).not.toContain('token')
  })

  it('uses the dev marker for the dev namespace', async () => {
    const fake = drive([listing])
    await new DriveClient(fake.provider, 'dev', fake.transport).head()
    expect(new URL(fake.calls[0]!.url).searchParams.get('q')).toContain("value='ledger-dev'")
  })

  it('reports no file rather than creating one', async () => {
    const fake = drive([() => ok({ files: [] })])
    const client = new DriveClient(fake.provider, '', fake.transport)
    expect(await client.head()).toBeUndefined()
    await expect(client.upload('{}')).rejects.toBeInstanceOf(RemoteStoreError)
    expect(fake.calls.every((call) => call.method === 'GET')).toBe(true)
  })

  it('replaces the content of the found file and returns the new head', async () => {
    const fake = drive([
      listing,
      (call) => (call.method === 'PATCH' ? ok({ id: 'f1', headRevisionId: 'r3' }) : undefined),
    ])
    const client = new DriveClient(fake.provider, '', fake.transport)
    await client.head()
    expect(await client.upload('{"a" : 1}')).toBe('r3')
    const patch = fake.calls.find((call) => call.method === 'PATCH')!
    expect(patch.url).toBe(
      'https://www.googleapis.com/upload/drive/v3/files/f1?uploadType=media&fields=id,headRevisionId',
    )
    expect(patch.body).toBe('{"a" : 1}')
  })

  it('lists revisions after a base across pages', async () => {
    const fake = drive([
      listing,
      (call) =>
        call.url.includes('pageToken=p2')
          ? ok({ revisions: [{ id: 'r3' }, { id: 'r4' }] })
          : call.url.includes('/revisions?')
            ? ok({ revisions: [{ id: 'r1' }, { id: 'r2' }], nextPageToken: 'p2' })
            : undefined,
    ])
    const client = new DriveClient(fake.provider, '', fake.transport)
    await client.head()
    expect(await client.revisionsAfter('r2')).toEqual(['r3', 'r4'])
    expect(await client.revisionsAfter('pruned')).toEqual([])
  })

  it('retries a 401 once with a fresh token, then reports signed out', async () => {
    const fake = drive([() => ok({}, 401)])
    const client = new DriveClient(fake.provider, '', fake.transport)
    await expect(client.head()).rejects.toMatchObject({ reason: { kind: 'signedOut' } })
    expect(fake.calls.map((call) => call.authorization)).toEqual([
      'Bearer token-1',
      'Bearer token-2',
    ])
    expect(fake.invalidated()).toBe(1)
  })

  it('maps a lost connection to offline after retrying', async () => {
    const fake = drive([])
    const client = new DriveClient(fake.provider, '', fake.transport)
    await expect(client.head()).rejects.toMatchObject({ reason: { kind: 'offline' } })
    expect(fake.calls).toHaveLength(3)
  })
})
