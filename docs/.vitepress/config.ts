import { defineConfig } from 'vitepress'

export default defineConfig({
  base: '/kage/',
  lang: 'zh-CN',
  title: 'Kage',
  description: '企业级代码质量治理 IDE',
  lastUpdated: true,
  head: [
    ['link', { rel: 'icon', href: '/kage/logo.png' }],
    ['meta', { property: 'og:title', content: 'Kage —— 企业级代码质量治理 IDE' }],
    ['meta', { property: 'og:description', content: '扫描 → 分析 → 修复 → 验证，覆盖代码质量、安全、架构、性能、测试五大维度。' }],
    ['meta', { property: 'og:image', content: '/kage/logo.png' }],
    ['meta', { property: 'og:type', content: 'website' }],
  ],
  themeConfig: {
    logo: '/logo.svg',
    siteTitle: 'Kage',
    nav: [
      { text: '首页', link: '/' },
      {
        text: '指南',
        items: [
          { text: '介绍', link: '/guide/intro' },
          { text: '快速开始', link: '/guide/getting-started' },
          { text: '多语言支持', link: '/guide/languages' },
          { text: '开发与打包', link: '/guide/dev' },
        ],
      },
      {
        text: '功能',
        items: [
          { text: '代码质量', link: '/guide/code-quality' },
          { text: '安全审查', link: '/guide/security' },
          { text: '架构分析', link: '/guide/architecture' },
          { text: '性能分析', link: '/guide/performance' },
          { text: '质量测试', link: '/guide/testing' },
        ],
      },
      { text: '下载', link: '/guide/download' },
    ],
    sidebar: {
      '/guide/': [
        {
          text: '开始',
          items: [
            { text: '介绍', link: '/guide/intro' },
            { text: '快速开始', link: '/guide/getting-started' },
            { text: '下载', link: '/guide/download' },
          ],
        },
        {
          text: '功能详解',
          items: [
            { text: '代码质量', link: '/guide/code-quality' },
            { text: '安全审查', link: '/guide/security' },
            { text: '架构分析', link: '/guide/architecture' },
            { text: '性能分析', link: '/guide/performance' },
            { text: '质量测试', link: '/guide/testing' },
          ],
        },
        {
          text: '更多',
          items: [
            { text: '多语言支持', link: '/guide/languages' },
            { text: '开发与打包', link: '/guide/dev' },
          ],
        },
      ],
    },
    socialLinks: [{ icon: 'github', link: 'https://github.com/SukiQ/kage' }],
    footer: {
      message: 'Kage · 企业级代码质量治理 IDE',
      copyright: 'Copyright © 2026 Kage',
    },
    outline: { level: [2, 3], label: '本页导航' },
    docFooter: { prev: '上一篇', next: '下一篇' },
    lastUpdatedText: '最后更新',
    darkModeSwitchLabel: '主题',
    sidebarMenuLabel: '菜单',
    returnToTopLabel: '回到顶部',
    langMenuLabel: '语言',
  },
})
