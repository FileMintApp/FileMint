import test from 'node:test'
import assert from 'node:assert/strict'
import {
  createLatestReleaseLoader,
  fetchLatestRelease,
  LATEST_RELEASE_API,
  parseLatestRelease,
} from '../.vitepress/theme/release.mjs'

const published = {
  tag_name: 'v1.2.3',
  draft: false,
  prerelease: false,
  published_at: '2026-10-12T08:30:00Z',
}

test('accepts a published stable release and constructs a trusted tag URL', () => {
  assert.deepEqual(parseLatestRelease({ ...published, html_url: 'https://untrusted.example' }), {
    version: '1.2.3',
    tag: 'v1.2.3',
    publishedAt: '2026-10-12T08:30:00.000Z',
    url: 'https://github.com/FileMintApp/FileMint/releases/tag/v1.2.3',
  })
  assert.equal(parseLatestRelease({ ...published, tag_name: '1.2.3' }).version, '1.2.3')
})

test('rejects drafts, prereleases, unpublished and malformed metadata', () => {
  const invalid = [
    null, [], {},
    { ...published, draft: true },
    { ...published, prerelease: true },
    { ...published, draft: undefined },
    { ...published, prerelease: 'false' },
    { ...published, published_at: null },
    { ...published, published_at: 'not-a-date' },
    { ...published, published_at: '2026-02-31T08:30:00Z' },
    { ...published, tag_name: 'v1.2.3-beta.1' },
    { ...published, tag_name: 'v1.2.3+dev' },
    { ...published, tag_name: 'v01.2.3' },
    { ...published, tag_name: '../anything' },
    { ...published, tag_name: '<img src=x onerror=alert(1)>' },
  ]
  for (const value of invalid) assert.equal(parseLatestRelease(value), null)
})

test('requests the public latest endpoint without credentials', async () => {
  const result = await fetchLatestRelease({ fetchImpl: async (url, options) => {
    assert.equal(url, LATEST_RELEASE_API)
    assert.equal(options.credentials, 'omit')
    assert.equal(options.redirect, 'error')
    assert.equal(options.headers.Authorization, undefined)
    assert.equal(options.signal.aborted, false)
    return { ok: true, json: async () => published }
  } })
  assert.equal(result.version, '1.2.3')
})

test('HTTP, network and JSON failures return a neutral fallback', async () => {
  for (const fetchImpl of [
    async () => ({ ok: false, status: 403, json: () => { throw Error('must not parse') } }),
    async () => { throw Error('offline') },
    async () => ({ ok: true, json: async () => { throw Error('invalid JSON') } }),
    async () => ({ ok: true, json: async () => ({ ...published, draft: true }) }),
  ]) assert.equal(await fetchLatestRelease({ fetchImpl }), null)
})

test('timeout bounds a hanging fetch and aborts its signal', async () => {
  let signal
  assert.equal(await fetchLatestRelease({
    timeoutMs: 10,
    fetchImpl: async (_url, options) => {
      signal = options.signal
      return new Promise(() => {})
    },
  }), null)
  assert.equal(signal.aborted, true)
})

test('timeout also bounds hanging response body parsing', async () => {
  assert.equal(await fetchLatestRelease({
    timeoutMs: 10,
    fetchImpl: async () => ({ ok: true, json: () => new Promise(() => {}) }),
  }), null)
})

test('the shared loader makes one request, including when that request fails', async () => {
  for (const ok of [true, false]) {
    let count = 0
    const load = createLatestReleaseLoader({ fetchImpl: async () => {
      count += 1
      return { ok, json: async () => published }
    } })
    assert.equal(count, 0, 'creating a loader must not perform build-time network access')
    const first = load()
    const second = load()
    assert.equal(first, second)
    await first
    assert.equal(load(), first)
    assert.equal(count, 1)
  }
})
