// Port of Packages/Data/DriveSync/Sources/HTTPTransport.swift: one request with retries for
// transient failures (rate limits, 5xx, a dropped connection) and exponential backoff, then a
// mapping of what is left to `RemoteStoreError`.
import { RemoteStoreError } from '../domain/errors'

export const maxAttempts = 3

export interface HttpResponse {
  readonly status: number
  readonly body: Uint8Array
}

export type Perform = (url: string, init: RequestInit) => Promise<HttpResponse>

const fetchPerform: Perform = async (url, init) => {
  const response = await fetch(url, { ...init, cache: 'no-store', credentials: 'omit' })
  return { status: response.status, body: new Uint8Array(await response.arrayBuffer()) }
}

export class HttpTransport {
  constructor(
    private readonly perform: Perform = fetchPerform,
    private readonly sleep: (millis: number) => Promise<void> = (millis) =>
      new Promise((resolve) => setTimeout(resolve, millis)),
  ) {}

  /**
   * Returns any final status; the caller decides what a 4xx means. A request that is not
   * `idempotent` is retried only on a rate limit, which Google answers before acting.
   */
  async send(url: string, init: RequestInit, idempotent = true): Promise<HttpResponse> {
    for (let attempt = 1; ; attempt++) {
      let response: HttpResponse
      try {
        response = await this.perform(url, init)
      } catch (error) {
        // fetch rejects only when no response arrived: offline, DNS, a dropped connection.
        if (error instanceof DOMException && error.name === 'AbortError') throw error
        if (idempotent && attempt < maxAttempts) {
          await this.sleep(backoff(attempt))
          continue
        }
        throw new RemoteStoreError({ kind: 'offline' })
      }
      const retryable = idempotent
        ? isTransient(response)
        : response.status === 429 || (response.status === 403 && isRateLimit(response.body))
      if (retryable && attempt < maxAttempts) {
        await this.sleep(backoff(attempt))
        continue
      }
      return response
    }
  }
}

/** 2xx passes; anything else becomes the matching `RemoteStoreError`. */
export function check(response: HttpResponse): void {
  const { status, body } = response
  if (status >= 200 && status < 300) return
  if (status === 401) throw new RemoteStoreError({ kind: 'signedOut' })
  if (status === 404) throw new RemoteStoreError({ kind: 'notFound' })
  if (status === 429 || (status === 403 && isRateLimit(body))) {
    throw new RemoteStoreError({ kind: 'rateLimited' })
  }
  throw new RemoteStoreError({ kind: 'server', status })
}

const isTransient = ({ status, body }: HttpResponse) =>
  status === 429 || (status >= 500 && status <= 599) || (status === 403 && isRateLimit(body))

/** Drive reports quota errors as 403 with a reason in the body. */
function isRateLimit(body: Uint8Array): boolean {
  const text = new TextDecoder().decode(body)
  return text.includes('rateLimitExceeded') || text.includes('userRateLimitExceeded')
}

/** 0.5 s, 1 s, 2 s, ... plus up to 250 ms of jitter. */
const backoff = (attempt: number) => 500 * 2 ** (attempt - 1) + Math.floor(Math.random() * 251)
