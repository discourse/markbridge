import { readFileSync } from 'node:fs';

const source = readFileSync(new URL('../../lib/markbridge/version.rb', import.meta.url), 'utf8');
const match = source.match(/^\s*VERSION\s*=\s*"([^"]+)"/m);
if (!match) throw new Error('Could not read Markbridge::VERSION');

export const docsVersion = match[1];
export const versionNote = `Source version: Markbridge ${docsVersion}. These docs are built from the repository and may include unreleased changes.`;
