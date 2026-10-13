export const LATEST_RELEASE_URL = 'https://github.com/FileMintApp/FileMint/releases/latest'
export const LATEST_RELEASE_API = 'https://api.github.com/repos/FileMintApp/FileMint/releases/latest'

const stableTag = /^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/

// Treat GitHub metadata as data only. Construct links from a validated tag;
// never display API-provided HTML or follow an API-provided destination.
export function parseLatestRelease(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null
  if (value.draft !== false || value.prerelease !== false) return null
  if (typeof value.tag_name !== 'string' || !stableTag.test(value.tag_name)) return null
  if (typeof value.published_at !== 'string') return null
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$/.test(value.published_at)) return null
  const publishedAt = new Date(value.published_at)
  if (!Number.isFinite(publishedAt.getTime())) return null
  if (publishedAt.toISOString().replace('.000Z', 'Z') !== value.published_at.replace('.000Z', 'Z')) return null

  return {
    version: value.tag_name.replace(/^v/, ''),
    tag: value.tag_name,
    publishedAt: publishedAt.toISOString(),
    url: `https://github.com/FileMintApp/FileMint/releases/tag/${encodeURIComponent(value.tag_name)}`,
  }
}

export async function fetchLatestRelease({ fetchImpl = globalThis.fetch, timeoutMs = 5000 } = {}) {
  if (typeof fetchImpl !== 'function') return null
  const controller = new AbortController()
  let timeout
  // Bound the entire request, including body parsing, even when a fetch adapter
  // does not reject promptly after its signal is aborted.
  const deadline = new Promise((resolve) => {
    timeout = setTimeout(() => {
      controller.abort()
      resolve(null)
    }, timeoutMs)
  })
  try {
    const request = (async () => {
      const response = await fetchImpl(LATEST_RELEASE_API, {
        headers: { Accept: 'application/vnd.github+json' },
        credentials: 'omit',
        redirect: 'error',
        signal: controller.signal,
      })
      if (!response.ok) return null
      return parseLatestRelease(await response.json())
    })()
    return await Promise.race([request, deadline])
  } catch {
    return null
  } finally {
    clearTimeout(timeout)
  }
}

export function createLatestReleaseLoader(options) {
  let request
  return () => (request ??= fetchLatestRelease(options))
}

// Calling this only on mount keeps server-side rendering/builds offline. All
// mounted badges share the same request, including its failure fallback.
export const getLatestRelease = createLatestReleaseLoader()
