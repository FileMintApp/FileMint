import test from 'node:test'
import assert from 'node:assert/strict'
import config from '../.vitepress/config.ts'

const site = 'https://filemintapp.github.io/FileMint/'
const pairs = [
  ['index.md', ''],
  ['guide.md', 'guide.html'],
  ['install.md', 'install.html'],
  ['privacy.md', 'privacy.html']
]
const entries = (head, tag, key, value) => head
  .filter(([name, attrs]) => name === tag && attrs[key] === value)
  .map(([, attrs]) => attrs)

test('all translated pages keep distinct canonical URLs and reciprocal language links', async () => {
  for (const [source, route] of pairs) {
    for (const prefix of ['', 'en/']) {
      const title = prefix ? 'FileMint User Guide' : 'FileMint 使用指南'
      const description = prefix ? 'Create files in Finder.' : '在 Finder 中新建文件。'
      const head = await config.transformHead({
        pageData: { relativePath: prefix + source }, title, description
      })
      const canonical = site + prefix + route
      assert.deepEqual(entries(head, 'link', 'rel', 'canonical'), [
        { rel: 'canonical', href: canonical }
      ])
      assert.deepEqual(entries(head, 'link', 'rel', 'alternate'), [
        { rel: 'alternate', hreflang: 'zh-Hans', href: site + route },
        { rel: 'alternate', hreflang: 'en-US', href: site + 'en/' + route }
      ])
      for (const [property, content] of [
        ['og:url', canonical], ['og:title', title], ['og:description', description],
        ['og:locale', prefix ? 'en_US' : 'zh_CN']
      ]) assert.deepEqual(entries(head, 'meta', 'property', property), [{ property, content }])
      for (const [name, content] of [['twitter:title', title], ['twitter:description', description]]) {
        assert.deepEqual(entries(head, 'meta', 'name', name), [{ name, content }])
      }
    }
  }
})

test('pages without an existing translation do not advertise nonexistent alternatives', async () => {
  for (const relativePath of ['untranslated.md', 'en/untranslated.md']) {
    const head = await config.transformHead({ pageData: { relativePath }, title: 'FileMint', description: 'Guide' })
    assert.deepEqual(entries(head, 'link', 'rel', 'alternate'), [])
    assert.deepEqual(entries(head, 'meta', 'property', 'og:locale:alternate'), [])
  }
})

test('404 pages are noindex without a canonical or language alternative', async () => {
  for (const relativePath of ['404.md', 'en/404.md']) {
    const head = await config.transformHead({ pageData: { relativePath }, title: 'Not Found', description: '' })
    assert.deepEqual(head, [['meta', { name: 'robots', content: 'noindex' }]])
  }
})

test('sitemap uses the official production base and excludes error pages', () => {
  assert.equal(config.sitemap.hostname, site)
  const pages = ['', 'en/', 'guide.html', 'en/guide.html', '404.html', 'en/404.html']
    .map((url) => ({ url }))
  assert.deepEqual(config.sitemap.transformItems(pages).map(({ url }) => url), [
    '', 'en/', 'guide.html', 'en/guide.html'
  ])
})

test('social previews use an absolute image URL including the production base', () => {
  const image = site + 'filemint-icon.png'
  assert.deepEqual(entries(config.head, 'meta', 'property', 'og:image'), [
    { property: 'og:image', content: image }
  ])
  assert.deepEqual(entries(config.head, 'meta', 'name', 'twitter:image'), [
    { name: 'twitter:image', content: image }
  ])
})
