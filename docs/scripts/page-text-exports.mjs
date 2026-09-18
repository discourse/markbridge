import { readdirSync } from 'node:fs';
import { textExports, pageTextExportForPage } from '../src/data/text-exports.mjs';

// Match Starlight's file-based IDs, including directory index pages.
export const pageTextExports = readdirSync(new URL('../src/content/docs/', import.meta.url), { recursive: true })
  .filter((path) => /\.mdx?$/.test(path))
  .sort()
  .map((source) => ({
    ...pageTextExportForPage(source.replace(/\.mdx?$/, '').replace(/\/index$/, '')),
    source,
  }));

const slugs = [...textExports, ...pageTextExports].map(({ slug }) => slug);
if (new Set(slugs).size !== slugs.length) {
  throw new Error('Documentation text export filenames must be unique.');
}
