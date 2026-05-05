// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://markbridge.dev',
  integrations: [
    starlight({
      title: 'Markbridge',
      description:
        'Extensible Ruby pipeline that turns BBCode, HTML, and other markup into Discourse-ready Markdown via a parse → AST → render flow.',
      logo: {
        src: './src/assets/markbridge-icon.svg',
        alt: 'Markbridge',
        replacesTitle: false,
      },
      favicon: '/favicon.svg',
      head: [
        {
          tag: 'link',
          attrs: { rel: 'icon', type: 'image/x-icon', href: '/favicon.ico', sizes: '32x32' },
        },
        {
          tag: 'link',
          attrs: { rel: 'apple-touch-icon', href: '/apple-touch-icon.png', sizes: '512x512' },
        },
        {
          tag: 'meta',
          attrs: { property: 'og:image', content: 'https://markbridge.dev/og-image.png' },
        },
        {
          tag: 'meta',
          attrs: { name: 'twitter:image', content: 'https://markbridge.dev/og-image.png' },
        },
        {
          tag: 'meta',
          attrs: { name: 'twitter:card', content: 'summary_large_image' },
        },
      ],
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/discourse/markbridge' },
      ],
      customCss: ['./src/styles/custom.css'],
      editLink: {
        baseUrl: 'https://github.com/discourse/markbridge/edit/main/docs/',
      },
      lastUpdated: true,
      expressiveCode: {
        themes: ['github-dark', 'github-light'],
        styleOverrides: { borderRadius: '0.5rem' },
      },
      sidebar: [
        { label: 'Getting Started', slug: 'getting-started' },
        {
          label: 'Guides',
          items: [
            { label: 'BBCode → Markdown', slug: 'guides/bbcode' },
            { label: 'HTML → Markdown', slug: 'guides/html' },
            { label: 'MediaWiki → Markdown', slug: 'guides/mediawiki' },
            { label: 'TextFormatter → Markdown', slug: 'guides/textformatter' },
            { label: 'Extending Markbridge', slug: 'guides/extending' },
            { label: 'Configuration', slug: 'guides/configuration' },
          ],
        },
        {
          label: 'Concepts',
          items: [
            { label: 'Architecture', slug: 'concepts/architecture' },
            { label: 'The AST', slug: 'concepts/ast' },
            { label: 'Parsers', slug: 'concepts/parsers' },
            { label: 'Renderers', slug: 'concepts/renderers' },
            { label: 'Performance', slug: 'concepts/performance' },
          ],
        },
        {
          label: 'Reference',
          items: [
            {
              label: 'API docs (rubydoc.info)',
              link: 'https://rubydoc.info/gems/markbridge',
              attrs: { target: '_blank', rel: 'noopener' },
            },
            { label: 'Changelog', slug: 'changelog' },
          ],
        },
      ],
    }),
  ],
});
