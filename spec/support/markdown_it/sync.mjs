// Brings the markdown-it cooker and the Discourse engine in line with
// Discourse.
//
//   node sync.mjs [--check] [--ref <branch or commit>]
//
// Reads from discourse/discourse at the ref (default: main):
//
// - the markdown-it and linkify-it versions from pnpm-lock.yaml, as resolved
//   for frontend/discourse-markdown-it
// - the defaults of the site settings that cook.mjs turns into options
// - a SHA-256 of every file the options in cook.mjs come from, and of the
//   files the Discourse engine (spec/support/discourse_engine) is built
//   from or loads
//
// and from discourse/discourse-bbcode at its main: the commit and a SHA-256
// of its markdown features, which the engine loads too.
//
// Without --check it writes discourse.json and package.json and runs
// `npm install` when a version changed. A changed source hash means Discourse
// changed a file cook.mjs copies from, or one the engine builds from: read
// the diff (the script prints the compare link) and update cook.mjs or
// build.mjs if needed.
//
// With --check it writes nothing and exits with 1 when something is
// different. A new commit alone is no difference.
//
// GITHUB_TOKEN is used for the GitHub API when it is set.

import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { parseArgs } from "node:util";
import { settingDefaults } from "./site_settings.mjs";

const REPO = "discourse/discourse";
const BBCODE_REPO = "discourse/discourse-bbcode";
const IMPORTER = "frontend/discourse-markdown-it";
const SITE_SETTINGS = [
  "traditional_markdown_linebreaks",
  "enable_markdown_linkify",
  "enable_markdown_typographer",
  "markdown_typographer_quotation_marks",
  "markdown_linkify_tlds",
];
const SOURCES = [
  // What cook.mjs copies its options from.
  "frontend/discourse-markdown-it/src/setup.js",
  "frontend/discourse-markdown-it/src/engine.js",
  "frontend/discourse-markdown-it/src/features/newline.js",
  "frontend/discourse-markdown-it/src/features/paragraph.js",
  "frontend/discourse-markdown-it/src/features/custom-typographer-replacements.js",
  // What the engine is built from and what it loads.
  "lib/pretty_text/core_bundle.rb",
  "frontend/pretty-text-processor/build.mjs",
  "frontend/pretty-text-processor/pretty-text-ruby-interface.js",
  "frontend/pretty-text-processor/shims/i18n.js",
  "plugins/discourse-details/assets/javascripts/lib/discourse-markdown/details.js",
  "plugins/spoiler-alert/assets/javascripts/lib/discourse-markdown/spoiler-alert.js",
  "plugins/poll/assets/javascripts/lib/discourse-markdown/poll.js",
  "plugins/discourse-events/assets/javascripts/discourse/lib/discourse-markdown/discourse-post-event-block.js",
];
const BBCODE_SOURCES = [
  "assets/javascripts/lib/discourse-markdown/bbcode.js",
  "assets/javascripts/lib/discourse-markdown/bbcode-values.js",
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

const commitOf = async (repo, ref) =>
  (
    await get(
      `https://api.github.com/repos/${repo}/commits/${ref}`,
      "application/vnd.github.sha"
    )
  ).trim();
const fileOf = (repo, commit, path) =>
  get(`https://raw.githubusercontent.com/${repo}/${commit}/${path}`);

const commit = await commitOf(REPO, args.ref);
const bbcodeCommit = await commitOf(BBCODE_REPO, "main");
const file = (path) => fileOf(REPO, commit, path);

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

// config/site_settings.yml: the `default:` of each setting.
function siteSettings(yaml) {
  const defaults = settingDefaults(yaml, SITE_SETTINGS);
  const missing = SITE_SETTINGS.filter((name) => !(name in defaults));
  if (missing.length > 0) {
    fail(`no default for ${missing.join(", ")} in config/site_settings.yml`);
  }
  return defaults;
}

const sha256 = (text) => createHash("sha256").update(text).digest("hex");
const hashes = async (repo, commit, paths) =>
  Object.fromEntries(
    await Promise.all(
      paths.map(async (path) => [path, sha256(await fileOf(repo, commit, path))])
    )
  );

const latest = {
  commit,
  packages: packages(await file("pnpm-lock.yaml")),
  site_settings: siteSettings(await file("config/site_settings.yml")),
  sources: await hashes(REPO, commit, SOURCES),
  discourse_bbcode: {
    commit: bbcodeCommit,
    sources: await hashes(BBCODE_REPO, bbcodeCommit, BBCODE_SOURCES),
  },
};

const current = JSON.parse(readFileSync(here("discourse.json"), "utf8"));

// The sections compared key by key; the commits are not among them.
const sections = {
  packages: [current.packages, latest.packages],
  site_settings: [current.site_settings, latest.site_settings],
  sources: [current.sources, latest.sources],
  "discourse-bbcode sources": [
    current.discourse_bbcode?.sources,
    latest.discourse_bbcode.sources,
  ],
};

const differences = [];
for (const [section, [before, after]] of Object.entries(sections)) {
  const keys = new Set([...Object.keys(before ?? {}), ...Object.keys(after)]);
  for (const key of keys) {
    const was = JSON.stringify(before?.[key]);
    const is = JSON.stringify(after[key]);
    if (was !== is) {
      differences.push({ section, key, before: was, after: is });
    }
  }
}

if (differences.length === 0) {
  console.log(`In sync with ${REPO}@${commit} and ${BBCODE_REPO}@${bbcodeCommit}.`);
  process.exit(0);
}

for (const { section, key, before, after } of differences) {
  console.log(`${section} ${key}: ${before} -> ${after}`);
}
if (differences.some(({ section }) => section === "sources")) {
  console.log(
    `\nRead what changed and update cook.mjs or build.mjs if needed:\n` +
      `https://github.com/${REPO}/compare/${current.commit}...${commit}`
  );
}
if (
  current.discourse_bbcode &&
  differences.some(({ section }) => section === "discourse-bbcode sources")
) {
  console.log(
    `\nRead what changed in the plugin:\n` +
      `https://github.com/${BBCODE_REPO}/compare/${current.discourse_bbcode.commit}...${bbcodeCommit}`
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

console.log(`\nUpdated to ${REPO}@${commit} and ${BBCODE_REPO}@${bbcodeCommit}.`);
