// Brings the markdown-it cooker in line with Discourse.
//
//   node sync.mjs [--check] [--ref <branch or commit>]
//
// Reads from discourse/discourse at the ref (default: main):
//
// - the markdown-it and linkify-it versions from pnpm-lock.yaml, as resolved
//   for frontend/discourse-markdown-it
// - the defaults of the site settings that cook.mjs turns into options
// - a SHA-256 of every file the options in cook.mjs come from
//
// Without --check it writes discourse.json and package.json and runs
// `npm install` when a version changed. A changed source hash means Discourse
// changed a file cook.mjs copies from: read the diff (the script prints the
// compare link) and update cook.mjs if needed.
//
// With --check it writes nothing and exits with 1 when something is
// different. A new commit alone is no difference.
//
// GITHUB_TOKEN is used for the GitHub API when it is set.

import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { parseArgs } from "node:util";

const REPO = "discourse/discourse";
const IMPORTER = "frontend/discourse-markdown-it";
const SITE_SETTINGS = [
  "traditional_markdown_linebreaks",
  "enable_markdown_linkify",
  "enable_markdown_typographer",
  "markdown_typographer_quotation_marks",
  "markdown_linkify_tlds",
];
const SOURCES = [
  "frontend/discourse-markdown-it/src/setup.js",
  "frontend/discourse-markdown-it/src/engine.js",
  "frontend/discourse-markdown-it/src/features/newline.js",
  "frontend/discourse-markdown-it/src/features/paragraph.js",
  "frontend/discourse-markdown-it/src/features/custom-typographer-replacements.js",
];

const { values: args } = parseArgs({
  options: {
    check: { type: "boolean", default: false },
    ref: { type: "string", default: "main" },
  },
});

const here = (name) => new URL(name, import.meta.url);

async function get(url, accept) {
  const headers = { "User-Agent": "markbridge-sync" };
  if (accept) {
    headers.Accept = accept;
  }
  if (process.env.GITHUB_TOKEN && url.startsWith("https://api.github.com/")) {
    headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
  }

  const response = await fetch(url, { headers });
  if (!response.ok) {
    throw new Error(`${url}: ${response.status} ${response.statusText}`);
  }
  return response.text();
}

const commit = (
  await get(
    `https://api.github.com/repos/${REPO}/commits/${args.ref}`,
    "application/vnd.github.sha"
  )
).trim();
const file = (path) =>
  get(`https://raw.githubusercontent.com/${REPO}/${commit}/${path}`);

function fail(message) {
  throw new Error(`${message} (${REPO}@${commit})`);
}

// pnpm-lock.yaml: the importer names the markdown-it version, the snapshot
// of that version names its linkify-it.
function packages(lock) {
  const importer = lock.split(`\n  ${IMPORTER}:\n`)[1]?.split("\n\n")[0];
  const markdownIt = importer?.match(
    /\n {6}markdown-it:\n {8}specifier: .+\n {8}version: (\S+)/
  )?.[1];
  if (!markdownIt) {
    fail(`no markdown-it version for ${IMPORTER} in pnpm-lock.yaml`);
  }

  // The last "snapshots:" is the top-level section, an earlier one can
  // belong to a nested setting.
  const snapshot = lock
    .slice(lock.lastIndexOf("\nsnapshots:\n"))
    .split(`\n  markdown-it@${markdownIt}:\n`)[1]
    ?.split("\n\n")[0];
  const linkifyIt = snapshot?.match(/\n? {6}linkify-it: (\S+)/)?.[1];
  if (!linkifyIt) {
    fail(`no linkify-it version for markdown-it@${markdownIt} in pnpm-lock.yaml`);
  }

  return { "linkify-it": linkifyIt, "markdown-it": markdownIt };
}

// config/site_settings.yml: the `default:` of each setting, which is a
// boolean or a (possibly quoted) string in all the settings we read.
function siteSettings(yaml) {
  return Object.fromEntries(
    SITE_SETTINGS.map((name) => {
      const block = yaml.split(`\n  ${name}:\n`)[1]?.split(/\n {2}\S/)[0];
      const raw = block?.match(/\n? {4}default: (.*)/)?.[1]?.trim();
      if (raw === undefined) {
        fail(`no default for ${name} in config/site_settings.yml`);
      }

      if (raw === "true" || raw === "false") {
        return [name, raw === "true"];
      }
      return [name, raw.replace(/^(["'])(.*)\1$/, "$2")];
    })
  );
}

const sha256 = (text) => createHash("sha256").update(text).digest("hex");

const latest = {
  commit,
  packages: packages(await file("pnpm-lock.yaml")),
  site_settings: siteSettings(await file("config/site_settings.yml")),
  sources: Object.fromEntries(
    await Promise.all(SOURCES.map(async (path) => [path, sha256(await file(path))]))
  ),
};

const current = JSON.parse(readFileSync(here("discourse.json"), "utf8"));

const differences = [];
for (const section of ["packages", "site_settings", "sources"]) {
  const keys = new Set([
    ...Object.keys(current[section] ?? {}),
    ...Object.keys(latest[section]),
  ]);
  for (const key of keys) {
    const before = JSON.stringify(current[section]?.[key]);
    const after = JSON.stringify(latest[section][key]);
    if (before !== after) {
      differences.push({ section, key, before, after });
    }
  }
}

if (differences.length === 0) {
  console.log(`In sync with ${REPO}@${commit}.`);
  process.exit(0);
}

for (const { section, key, before, after } of differences) {
  console.log(`${section} ${key}: ${before} -> ${after}`);
}
if (differences.some(({ section }) => section === "sources")) {
  console.log(
    `\nRead what changed and update cook.mjs if needed:\n` +
      `https://github.com/${REPO}/compare/${current.commit}...${commit}`
  );
}

if (args.check) {
  console.log(`\nRun \`node spec/support/markdown_it/sync.mjs\` to update.`);
  process.exit(1);
}

writeFileSync(here("discourse.json"), `${JSON.stringify(latest, null, 2)}\n`);

const manifest = JSON.parse(readFileSync(here("package.json"), "utf8"));
manifest.dependencies = { ...manifest.dependencies, ...latest.packages };
writeFileSync(here("package.json"), `${JSON.stringify(manifest, null, 2)}\n`);

if (differences.some(({ section }) => section === "packages")) {
  execFileSync("npm", ["install", "--no-audit", "--no-fund"], {
    cwd: here("."),
    stdio: "inherit",
  });
}

console.log(`\nUpdated to ${REPO}@${commit}.`);
