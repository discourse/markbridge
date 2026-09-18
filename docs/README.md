# Documentation site

The site uses Astro and Starlight. Content lives in `src/content/docs/`, navigation in `astro.config.mjs`, and site styles in `src/styles/custom.css`.

Use Node.js 22.12 or newer and the pnpm version in `package.json`. From this directory:

```sh
pnpm install --frozen-lockfile
pnpm dev
```

`pnpm build` creates the production site in `dist/`. `pnpm preview` serves that build locally. Both development and production builds generate the changelog from GitHub Releases. If GitHub is unavailable, the generator keeps an existing page or writes a link to the releases.

If Markdown edits stop appearing in development, run `pnpm astro dev stop` and restart `pnpm dev`.

The site shows a work-in-progress notice and includes a `noindex` robots meta tag on every page. Keep crawling allowed in `public/robots.txt` so search engines can read that tag. When the docs are ready for indexing, remove the robots meta entry and the `Banner` override from `astro.config.mjs`, delete `src/components/DocsBanner.astro`, and restore the sitemap URL in `public/robots.txt`.

Run `bundle exec rspec spec/docs` from the repository root to check AST coverage and Ruby examples. Every `ruby` code block runs in a separate process. Use a `spec:before` comment for setup or `spec:continue` to include earlier examples. Use `rb` for API signatures and examples of removed APIs that cannot run.
