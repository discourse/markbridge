import assert from 'node:assert/strict';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { docsVersion } from './docs-version.mjs';
import { pageTextExports } from './page-text-exports.mjs';
import { textExports, textExportHref } from '../src/data/text-exports.mjs';

const docsDir = fileURLToPath(new URL('../', import.meta.url));
const outputDir = join(docsDir, 'dist');
const readOutput = (path) => readFileSync(join(outputDir, path), 'utf8');
const index = readOutput('llms.txt');
const full = readOutput('llms-full.txt');
const paths = ['llms.txt', 'llms-full.txt', 'llms-small.txt'];

for (const { slug } of [...textExports, ...pageTextExports]) {
  const href = textExportHref(slug);
  assert.ok(index.includes(href), `Missing index link: ${href}`);
  paths.push(href.slice(1));
}

for (const path of paths) {
  const text = readOutput(path);
  assert.ok(text.includes(`Markbridge ${docsVersion}`), `Missing source version: ${path}`);
  assert.doesNotMatch(text, /spec:(?:before|continue)/, `Test setup in ${path}`);
  assert.doesNotMatch(text, /Section titled/, `Heading helper text in ${path}`);
  assert.doesNotMatch(text, /<CardGrid>|<LinkCard\s|^import .*@astrojs\/starlight/m, `MDX source in ${path}`);
}

// Rendering HTML back to Markdown can change blank lines, but must keep code and indentation.
function rubyBlocks(markdown) {
  const lines = markdown.split('\n');
  const blocks = [];
  for (let i = 0; i < lines.length; i++) {
    const opening = lines[i].match(/^(`{3,}|~{3,})(?:ruby|rb)\s*$/);
    if (!opening) continue;
    const content = [];
    while (++i < lines.length && lines[i] !== opening[1]) content.push(lines[i]);
    blocks.push(content.filter((line) => line.trim()).join('\n'));
  }
  return blocks;
}

function sourceFiles(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    return entry.isDirectory() ? sourceFiles(path) : /\.mdx?$/.test(path) ? [path] : [];
  });
}

const expectedBlocks = sourceFiles(join(docsDir, 'src/content/docs'))
  .flatMap((path) => rubyBlocks(readFileSync(path, 'utf8')));
const actualBlocks = rubyBlocks(full);
assert.deepEqual(actualBlocks.toSorted(), expectedBlocks.toSorted(), 'Exported Ruby examples differ from source');

for (const { id, source, slug } of pageTextExports) {
  const text = readOutput(textExportHref(slug));
  const markdown = readFileSync(join(docsDir, 'src/content/docs', source), 'utf8');
  assert.deepEqual(rubyBlocks(text), rubyBlocks(markdown), `Ruby examples differ on ${id}`);
  assert.ok(text.includes(`https://markbridge.dev/${id === 'index' ? '' : `${id}/`}`), `Missing page URL: ${id}`);
  const html = readOutput(id === 'index' ? 'index.html' : `${id}/index.html`);
  assert.ok(html.includes(`href="${textExportHref(slug)}"`), `Missing individual export link: ${id}`);
  assert.match(html, /rel="alternate"[^>]*title="This page as Markdown"/, `Missing alternate link: ${id}`);
  assert.ok(html.includes('This page as Markdown'), `Missing footer link: ${id}`);
}

const htmlGuide = readOutput('_llms-txt/html.txt');
assert.match(htmlGuide, /\|[^\n]*HTML[^\n]*Renders as[^\n]*AST node[^\n]*\|/, 'HTML tag table missing');
assert.match(full, /\[BBCode\]\(\/format-guides\/bbcode\/\)/, 'Landing-page card link missing');
assert.ok(full.includes('Convert bracket tags for formatting'), 'Landing-page card description missing');

for (const match of index.matchAll(/\]\((https:\/\/markbridge\.dev\/[^)]+)\)/g)) {
  const path = new URL(match[1]).pathname;
  assert.ok(existsSync(join(outputDir, path)), `Missing text export: ${path}`);
}

const htmlPages = readdirSync(outputDir, { recursive: true }).filter((path) => path.endsWith('.html'));
for (const path of htmlPages) {
  const html = readOutput(path);
  assert.ok(html.includes('href="/llms.txt"'), `Missing text index link: ${path}`);
  for (const match of html.matchAll(/href="(\/_llms-txt\/[^"]+)"/g)) {
    assert.ok(existsSync(join(outputDir, match[1])), `Broken text link on ${path}: ${match[1]}`);
  }
}

const page = readOutput('format-guides/html/index.html');
assert.match(page, /rel="describedby"[^>]*href="\/llms\.txt"/, 'Text index discovery link missing');
assert.ok(page.includes('href="/_llms-txt/html.txt"'), 'HTML guide export link missing');
assert.ok(page.includes('HTML as Markdown'), 'Visible text export link missing');
assert.ok(page.includes(`Source version: Markbridge ${docsVersion}`), 'Visible source version missing');

console.log(`Checked ${paths.length} text exports and ${expectedBlocks.length} Ruby examples.`);
