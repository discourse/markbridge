#!/usr/bin/env node
// Generate docs/src/content/docs/changelog.md from GitHub Releases.
// Runs as a pre-step before `astro dev` and `astro build`, so the page
// reflects whatever the release notes currently look like on GitHub.
//
// Fail-soft: if the API is unreachable, keep an existing file as-is or
// write a stub. The build never fails because of this.

import { writeFile, mkdir, access } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const REPO = "discourse/markbridge";
const API_URL = `https://api.github.com/repos/${REPO}/releases?per_page=100`;
const HERE = dirname(fileURLToPath(import.meta.url));
const TARGET = resolve(HERE, "../src/content/docs/changelog.md");

const FRONTMATTER = [
  "---",
  "title: Changelog",
  "description: Release notes for Markbridge, sourced from GitHub Releases.",
  "---",
  "",
];

async function fetchReleases() {
  const headers = { Accept: "application/vnd.github+json" };
  if (process.env.GITHUB_TOKEN) {
    headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
  }
  const res = await fetch(API_URL, { headers });
  if (!res.ok) {
    throw new Error(`GitHub API ${res.status}: ${await res.text()}`);
  }
  const releases = await res.json();
  return releases.filter((r) => !r.draft);
}

function renderEmpty() {
  return [
    ...FRONTMATTER,
    "No releases yet. Watch [GitHub Releases](https://github.com/" +
      REPO +
      "/releases) for updates.",
    "",
  ].join("\n");
}

function renderStub() {
  return [
    ...FRONTMATTER,
    "Could not fetch release notes at build time.",
    `See [GitHub Releases](https://github.com/${REPO}/releases) for the latest.`,
    "",
  ].join("\n");
}

// Turn bare `#123` PR/issue references into GitHub links. GitHub redirects
// /pull/N <-> /issues/N, so /pull/N works whether N is a PR or an issue.
// The lookbehind skips word chars (so no `abc#1`), `&` (numeric HTML entities
// like `&#39;`), and `/` (so we don't touch `.../#30` in URLs).
const ISSUE_REF = /(?<![\w&/])#(\d+)\b/g;

function linkifyIssueRefs(text) {
  return text.replace(
    ISSUE_REF,
    (_m, n) => `[#${n}](https://github.com/${REPO}/pull/${n})`,
  );
}

// Apply linkifyIssueRefs to a body while leaving code untouched: split on
// fenced code blocks first, then on inline code spans within prose segments.
function linkifyOutsideCode(body) {
  return body
    .split(/(```[\s\S]*?```)/g)
    .map((block) =>
      block.startsWith("```")
        ? block
        : block
            .split(/(`[^`\n]*`)/g)
            .map((seg) => (seg.startsWith("`") ? seg : linkifyIssueRefs(seg)))
            .join(""),
    )
    .join("");
}

// Normalize each release body for the in-docs changelog:
//   - drop the redundant "What's Changed" heading (from bin/generate-release-notes
//     and GitHub's auto-generated notes)
//   - strip leading emojis from headings (the docs theme handles emphasis)
//   - demote every heading by one level so categories sit comfortably under the
//     version heading without competing visually
//   - linkify bare `#123` references to their GitHub PR/issue
function formatBody(body) {
  return linkifyOutsideCode(
    body
      .replace(/^#{2,6} What's Changed\s*\n+/gm, "")
      .replace(/^(#{2,6}) [\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]+\s+/gmu, "$1 ")
      .replace(/^(#{1,5})(\s)/gm, "$1#$2"),
  ).trim();
}

function renderRelease(r) {
  const date = r.published_at?.slice(0, 10);
  const title = r.name?.trim() || r.tag_name;
  const heading = date ? `### ${title} — ${date}` : `### ${title}`;
  const body = formatBody((r.body ?? "").trim());
  return body ? `${heading}\n\n${body}` : heading;
}

function render(releases) {
  if (releases.length === 0) return renderEmpty();
  return [...FRONTMATTER, releases.map(renderRelease).join("\n\n---\n\n"), ""].join("\n");
}

async function fileExists(p) {
  try {
    await access(p);
    return true;
  } catch {
    return false;
  }
}

async function main() {
  try {
    const releases = await fetchReleases();
    await mkdir(dirname(TARGET), { recursive: true });
    await writeFile(TARGET, render(releases));
    console.log(`generate-changelog: wrote ${releases.length} release(s) to ${TARGET}`);
  } catch (err) {
    console.warn(`generate-changelog: ${err.message}`);
    if (!(await fileExists(TARGET))) {
      await mkdir(dirname(TARGET), { recursive: true });
      await writeFile(TARGET, renderStub());
      console.warn(`generate-changelog: wrote stub to ${TARGET}`);
    } else {
      console.warn("generate-changelog: keeping existing changelog");
    }
  }
}

main();
