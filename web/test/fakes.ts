// Test doubles shared by the domain tests, in the spirit of Packages/Domain/Tests/Fakes.swift.
import { dayDate, yearMonth } from '../src/domain/calendar'
import { RemoteStoreError, type RemoteStoreErrorKind } from '../src/domain/errors'
import { type Board, type Entry, newUuid } from '../src/domain/model'
import type { ClockPort, RemoteRevision, RemoteStorePort } from '../src/domain/ports'

export class MutableClock implements ClockPort {
  constructor(private value = 1_790_000_000_000) {}

  now() {
    return this.value
  }

  set(value: number) {
    this.value = value
  }

  advance(millis = 1000) {
    this.value += millis
  }
}

/** Cloud storage in memory: an append-only revision list, like Drive's history. */
export class FakeRemoteStore implements RemoteStorePort {
  readonly revisions: { revision: RemoteRevision; data: string }[] = []
  private nextError: RemoteStoreErrorKind | undefined
  /** Runs inside `upload`, before the upload lands: another device's upload in between. */
  private beforeNextUpload: (() => Promise<void>) | undefined

  get uploadCount() {
    return this.revisions.length
  }

  get headData() {
    return this.revisions.at(-1)?.data
  }

  failNext(error: RemoteStoreErrorKind) {
    this.nextError = error
  }

  interleave(body: () => Promise<void>) {
    this.beforeNextUpload = body
  }

  /** Writes a revision directly, as the Mac or a hand edit would. */
  put(data: string): RemoteRevision {
    const revision = `rev-${this.revisions.length + 1}`
    this.revisions.push({ revision, data })
    return revision
  }

  async head() {
    this.throwIfFailing()
    return this.revisions.at(-1)?.revision
  }

  async download(revision: RemoteRevision) {
    this.throwIfFailing()
    const found = this.revisions.find((item) => item.revision === revision)
    if (!found) throw new RemoteStoreError({ kind: 'notFound' })
    return new TextEncoder().encode(found.data)
  }

  async upload(data: string) {
    this.throwIfFailing()
    const before = this.beforeNextUpload
    this.beforeNextUpload = undefined
    await before?.()
    return this.put(data)
  }

  async revisionsAfter(revision: RemoteRevision) {
    this.throwIfFailing()
    const index = this.revisions.findIndex((item) => item.revision === revision)
    return index === -1 ? [] : this.revisions.slice(index + 1).map((item) => item.revision)
  }

  private throwIfFailing() {
    const error = this.nextError
    this.nextError = undefined
    if (error) throw new RemoteStoreError(error)
  }
}

export function sampleBoard(name = 'Company A', overrides: Partial<Board> = {}): Board {
  return {
    id: newUuid(),
    name,
    start: yearMonth(2017, 7),
    createdAt: 1,
    updatedAt: 1,
    ...overrides,
  }
}

export function sampleEntry(name: string, board: Board, overrides: Partial<Entry> = {}): Entry {
  return {
    id: newUuid(),
    boardId: board.id,
    name,
    type: 'dev',
    date: dayDate(2026, 3, 12),
    tags: [],
    problem: '',
    why: '',
    solution: '',
    impact: '',
    difficulties: '',
    metrics: [],
    createdAt: 1,
    updatedAt: 1,
    ...overrides,
  }
}
