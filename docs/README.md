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

## Text exports

The site generates Markdown text with `starlight-llms-txt`. Start with `/llms.txt` for links to the full documentation, a shorter collection, and topic files under `/_llms-txt/`. Each content page also has its own file, such as `/_llms-txt/page-concepts-ast.txt`. These `.txt` files contain Markdown. The footer links to the index, the current page, and its topic. HTML metadata identifies the individual file as an alternate representation. A topic can contain several pages; it is not necessarily a copy of the current page alone.

`src/data/text-exports.mjs` defines the topics. `scripts/page-text-exports.mjs` discovers individual Markdown and MDX pages in `src/content/docs/`. It maps directory index pages to their Starlight IDs and rejects unsupported IDs or duplicate export filenames. Restart the dev server after adding or renaming a page so its export is discovered. All exports use the plugin’s `customSets` option; there is no separate Markdown converter. A topic's label determines its generated filename, so keep its `slug` in sync when renaming it. `pnpm build` checks these links and verifies that Ruby examples, tag tables, and landing-page card links survive conversion. Run `pnpm check:text` to repeat those checks on an existing build.

The source version comes from `lib/markbridge/version.rb` and appears in the text files and page footer. It identifies the repository version; the docs may include changes that are not released yet. Version-file changes also trigger the docs workflow.

Exports remove hidden test comments, heading helper links, and duplicate dark-theme diagrams. Notes, warnings, code indentation, and normal paragraph spacing are retained. The shorter collection omits the changelog, upgrade history, and benchmark results; those remain in the full export and their topic files.

Plain-text exports do not contain the HTML pages' `noindex` metadata. Coordinate their publication with the indexing follow-up in [PR #89](https://github.com/discourse/markbridge/pull/89).
