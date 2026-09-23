import { defineConfig } from 'vitepress'

const repository = 'https://github.com/FileMintApp/FileMint'
const base = process.env.SITE_BASE ?? '/'
const publicAsset = (path: string) => `${base.replace(/\/$/, '')}/${path}`

export default defineConfig({
  base,
  title: 'FileMint',
  description: 'Create files from text and Office templates, open your apps and process images locally from Finder.',
  markdown: {
    config(md) {
      // Render the same GitHub task lists used by the README includes.
      md.core.ruler.after('inline', 'task-lists', (state) => {
        for (let index = 2; index < state.tokens.length; index++) {
          const token = state.tokens[index]
          const item = state.tokens[index - 2]
          const first = token.children?.[0]
          if (token.type !== 'inline' || item.type !== 'list_item_open' || first?.type !== 'text') continue
          const marker = /^\[([ xX])\]\s+/.exec(first.content)
          if (!marker) continue
          first.content = first.content.slice(marker[0].length)
          const label = md.utils.escapeHtml(token.children!.map((child) => child.content).join(''))
          const checkbox = new state.Token('html_inline', '', 0)
          checkbox.content = `<input class="task-checkbox" type="checkbox" disabled${marker[1] === ' ' ? '' : ' checked'} aria-label="${label}"> `
          token.children!.unshift(checkbox)
          item.attrJoin('class', 'task-list-item')
        }
      })
    }
  },
  head: [
    ['meta', { name: 'theme-color', content: '#0b9b7b' }],
    ['meta', { property: 'og:image', content: publicAsset('filemint-icon.png') }],
    ['meta', { property: 'og:image:type', content: 'image/png' }],
    ['meta', { property: 'og:image:width', content: '1024' }],
    ['meta', { property: 'og:image:height', content: '1024' }],
    ['meta', { name: 'apple-mobile-web-app-title', content: 'FileMint' }],
    ['link', { rel: 'icon', href: publicAsset('favicon.ico'), sizes: 'any' }],
    ['link', { rel: 'icon', type: 'image/png', href: publicAsset('favicon-16x16.png'), sizes: '16x16' }],
    ['link', { rel: 'icon', type: 'image/png', href: publicAsset('favicon-32x32.png'), sizes: '32x32' }],
    ['link', { rel: 'apple-touch-icon', href: publicAsset('apple-touch-icon.png'), sizes: '180x180' }],
    ['link', { rel: 'manifest', href: publicAsset('site.webmanifest') }]
  ],
  locales: {
    root: {
      label: '简体中文',
      lang: 'zh-Hans',
      title: 'FileMint',
      description: '在 Finder 中创建文件、复用文本与 Office 模板、使用常用 App 打开项目，并在本机处理图片。',
      themeConfig: {
        outline: { level: 'deep', label: '本页目录' },
        nav: [
          { text: '功能', link: '/#finder' },
          { text: '为什么是 FileMint', link: '/#privacy' },
          { text: '未来规划', link: '/#roadmap' },
          { text: '安装', link: '/install' },
          { text: '使用指南', link: '/guide' },
          { text: '隐私', link: '/privacy' },
          { text: 'GitHub', link: repository }
        ],
        footer: {
          message: '个人及非商业使用免费；商业使用须获得授权或单独购买商业许可。',
          copyright: 'Copyright © XiaoDaiGua-Ray'
        }
      }
    },
    en: {
      label: 'English',
      lang: 'en-US',
      link: '/en/',
      title: 'FileMint',
      description: 'Create files from text and Office templates, open your apps and process images locally from Finder.',
      themeConfig: {
        nav: [
          { text: 'Features', link: '/en/#finder' },
          { text: 'Why FileMint', link: '/en/#privacy' },
          { text: 'Roadmap', link: '/en/#roadmap' },
          { text: 'Install', link: '/en/install' },
          { text: 'User Guide', link: '/en/guide' },
          { text: 'Privacy', link: '/en/privacy' },
          { text: 'GitHub', link: repository }
        ],
        footer: {
          message: 'Free for personal and non-commercial use. Commercial use requires authorization.',
          copyright: 'Copyright © XiaoDaiGua-Ray'
        }
      }
    }
  },
  themeConfig: {
    logo: { src: '/filemint-icon.png', alt: 'FileMint' },
    siteTitle: 'FileMint',
    socialLinks: [{ icon: 'github', link: repository }],
    outline: { level: 'deep', label: 'On this page' },
    docFooter: { prev: false, next: false }
  }
})
