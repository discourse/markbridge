// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://markbridge.dev',
  vite: {
    server: {
      // Force fresh fetches in dev so updated SVGs / CSS / JS in public/
      // appear without restarting the dev server. Without this, Vite's
      // static-file middleware lets the browser cache `public/` assets
      // aggressively and even hard-refresh keeps the stale copy.
      headers: { 'Cache-Control': 'no-store' },
      // inotify isn't reliable on every filesystem (containers, mounted
      // volumes); poll instead so file changes are picked up everywhere.
      watch: { usePolling: true, interval: 200 },
    },
  },
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
        {
          tag: 'script',
          attrs: { src: '/diagram-zoom.js', defer: true },
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
          label: 'Migrating to Discourse',
          items: [
            { label: 'Overview', slug: 'migrating/overview' },
            { label: 'Placeholders', slug: 'migrating/placeholders' },
            { label: 'Full walkthrough', slug: 'migrating/full-walkthrough' },
          ],
        },
        {
          label: 'Format guides',
          items: [
            { label: 'BBCode → Markdown', slug: 'format-guides/bbcode' },
            { label: 'HTML → Markdown', slug: 'format-guides/html' },
            { label: 'MediaWiki → Markdown', slug: 'format-guides/mediawiki' },
            { label: 'TextFormatter → Markdown', slug: 'format-guides/textformatter' },
          ],
        },
        {
          label: 'Customization',
          items: [
            { label: 'Customizing the renderer', slug: 'customization/customizing-renderer' },
            { label: 'Extending Markbridge', slug: 'customization/extending' },
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
            { label: 'Upgrading', slug: 'reference/upgrading' },
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
