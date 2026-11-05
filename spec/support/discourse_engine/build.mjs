// Builds what cook.mjs needs to cook Markdown with Discourse's own engine:
//
// - a checkout of discourse/discourse at the commit in discourse.json (the
//   parts the pretty-text bundle is built from) and of discourse-bbcode
// - the pretty-text bundle, built the way `PrettyText::CoreBundle` builds
//   it: `pnpm install` in the checkout and `node build.mjs` in
//   frontend/pretty-text-processor
// - the markdown features of the plugins as AMD modules, the way
//   Discourse's AssetProcessor transpiles them, one file per plugin
// - the defaults of the site settings the engine reads
//
//   node build.mjs [--out tmp/discourse_engine] [--force]
//
// Everything lands in the --out directory, and a second run with the same
// commits does nothing. Discourse and the plugin are GPL code, they are
// only fetched into tmp/ and never copied into this repository.

import { execFileSync } from "node:child_process";
import { existsSync, globSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { basename, join, resolve } from "node:path";
import { parseArgs } from "node:util";
import { transformSync } from "@babel/core";
import modulesAmd from "@babel/plugin-transform-modules-amd";
import { settingDefaults } from "../markdown_it/site_settings.mjs";

const { values: args } = parseArgs({
  options: {
    out: { type: "string", default: "tmp/discourse_engine" },
    force: { type: "boolean", default: false },
  },
});

const here = (name) => new URL(name, import.meta.url);
const discourse = JSON.parse(readFileSync(here("../markdown_it/discourse.json"), "utf8"));
const out = resolve(args.out);
const manifestPath = join(out, "engine.json");

// The plugins bundled with Discourse whose BBCode the renderer writes.
const CORE_PLUGINS = ["discourse-details", "spoiler-alert", "poll", "discourse-events"];

// What the bundle is built from, see lib/pretty_text/core_bundle.rb and
// frontend/pretty-text-processor/build.mjs in Discourse.
const DISCOURSE_PATHS = [
  "frontend/pretty-text-processor",
  "frontend/pretty-text",
  "frontend/discourse-markdown-it",
  "frontend/discourse",
  "frontend/discourse-i18n",
  ...CORE_PLUGINS.map((plugin) => `plugins/${plugin}`),
  "config/site_settings.yml",
  "lib/pretty_text/core_bundle.rb",
  "pnpm-lock.yaml",
  "pnpm-workspace.yaml",
  "package.json",
  ".npmrc",
  "patches",
];

// The `siteSettings.*` keys the loaded JavaScript reads, from
// migrations/converters/lib/migrations/converters/markdown_engine/config.rb
// in Discourse, without the plugins that are not loaded here.
const SETTINGS = [
  "allowed_href_schemes",
  "allowed_iframes",
  "default_code_lang",
  "emoji_set",
  "enable_emoji",
  "enable_emoji_shortcuts",
  "enable_inline_emoji_translation",
  "enable_markdown_linkify",
  "enable_markdown_typographer",
  "enable_mentions",
  "external_emoji_url",
  "markdown_linkify_tlds",
  "markdown_typographer_quotation_marks",
  "max_oneboxes_per_post",
  "secure_uploads",
  "traditional_markdown_linebreaks",
  "unicode_usernames",
  "avatar_sizes",
  "details_enabled",
  "spoiler_enabled",
  "poll_enabled",
  "poll_maximum_options",
  "discourse_post_event_enabled",
  "discourse_events_enabled",
];

const wanted = {
  discourse: discourse.commit,
  "discourse-bbcode": discourse.discourse_bbcode.commit,
};

if (!args.force && existsSync(manifestPath)) {
  const built = JSON.parse(readFileSync(manifestPath, "utf8"));
  if (built.discourse === wanted.discourse && built["discourse-bbcode"] === wanted["discourse-bbcode"]) {
    console.log(`The engine in ${args.out} is built from these commits already.`);
    process.exit(0);
  }
}

function run(command, commandArgs, options = {}) {
  return execFileSync(command, commandArgs, { stdio: ["ignore", "pipe", "inherit"], ...options });
}

function git(dir, ...gitArgs) {
  return run("git", ["-C", dir, ...gitArgs]).toString().trim();
}

// A checkout of +repo+ at +commit+ with only +paths+, fetched without
// history. An existing checkout at that commit stays.
function checkout(repo, commit, dir, paths = null) {
  if (existsSync(join(dir, ".git"))) {
    try {
      if (git(dir, "rev-parse", "HEAD") === commit) {
        return;
      }
    } catch {
      // Not a repository we can read; it is rebuilt below.
    }
    rmSync(dir, { recursive: true, force: true });
  }

  console.log(`Fetching ${repo}@${commit.slice(0, 10)} into ${dir}`);
  mkdirSync(dir, { recursive: true });
  git(dir, "init", "-q");
  git(dir, "remote", "add", "origin", `https://github.com/${repo}.git`);
  if (paths) {
    git(dir, "sparse-checkout", "set", "--no-cone", ...paths);
  }
  git(dir, "fetch", "-q", "--depth", "1", "--filter=blob:none", "origin", commit);
  git(dir, "checkout", "-q", "FETCH_HEAD");
}

// `pnpm install` for the packages the bundle is built from, with the pnpm
// version the checkout names. The root postinstall script needs files
// outside the sparse checkout, so no scripts run.
function installPackages(root) {
  const manifest = JSON.parse(readFileSync(join(root, "package.json"), "utf8"));
  const pnpm = manifest.packageManager || "pnpm";
  console.log(`Installing the packages of the bundle with ${pnpm}`);
  run(
    "npx",
    [
      "-y",
      pnpm,
      "install",
      "--frozen-lockfile",
      "--ignore-scripts",
      "--filter",
      "pretty-text-processor",
      "--filter",
      "discourse-markdown-it",
      "--filter",
      "pretty-text",
      "--filter",
      "discourse-i18n",
    ],
    { cwd: root, stdio: ["ignore", "inherit", "inherit"] },
  );
}

// The modules of the `discourse` package the bundle may hold, read from
// the Ruby file that names them.
function discourseModules(root) {
  const source = readFileSync(join(root, "lib/pretty_text/core_bundle.rb"), "utf8");
  const list = source.match(/DISCOURSE_MODULES = %w\[([^\]]*)\]/)?.[1];
  if (!list) {
    throw new Error("no DISCOURSE_MODULES in lib/pretty_text/core_bundle.rb");
  }
  return list.split(/\s+/).filter(Boolean);
}

function buildBundle(root) {
  console.log("Building the pretty-text bundle");
  const bundle = run("node", ["build.mjs", `--discourse-modules=${discourseModules(root).join(",")}`], {
    cwd: join(root, "frontend/pretty-text-processor"),
    maxBuffer: 64 * 1024 * 1024,
  });
  writeFileSync(join(out, "pretty-text.js"), bundle);
}

// The markdown features of a plugin as AMD modules under the ids
// loadPluginFeatures() looks for: discourse/plugins/<plugin>/<path under
// assets/javascripts>.
function buildPlugin(dir) {
  const plugin = basename(dir);
  const root = join(dir, "assets/javascripts");
  const files = globSync("**/discourse-markdown/**/*.js", { cwd: root }).sort();
  const modules = files.map((file) => {
    const id = `discourse/plugins/${plugin}/${file.replace(/\.js$/, "")}`;
    const { code } = transformSync(readFileSync(join(root, file), "utf8"), {
      filename: file,
      sourceType: "module",
      configFile: false,
      babelrc: false,
      moduleIds: true,
      moduleId: id,
      plugins: [modulesAmd],
    });
    return `// ${id}\n${code}`;
  });
  if (modules.length === 0) {
    throw new Error(`no markdown features in ${dir}`);
  }
  writeFileSync(join(out, "plugins", `${plugin}.js`), modules.join("\n\n"));
  return plugin;
}

function buildSettings(root, pluginDirs) {
  const settings = settingDefaults(readFileSync(join(root, "config/site_settings.yml"), "utf8"), SETTINGS);
  for (const dir of pluginDirs) {
    const file = join(dir, "config/settings.yml");
    if (existsSync(file)) {
      Object.assign(settings, settingDefaults(readFileSync(file, "utf8"), SETTINGS));
    }
  }
  const missing = SETTINGS.filter((name) => !(name in settings));
  if (missing.length > 0) {
    throw new Error(`no default for ${missing.join(", ")} in the settings files`);
  }
  writeFileSync(join(out, "settings.json"), `${JSON.stringify(settings, null, 2)}\n`);
}

const discourseRoot = join(out, "discourse");
const bbcodeRoot = join(out, "discourse-bbcode");
mkdirSync(join(out, "plugins"), { recursive: true });

checkout("discourse/discourse", wanted.discourse, discourseRoot, DISCOURSE_PATHS);
checkout("discourse/discourse-bbcode", wanted["discourse-bbcode"], bbcodeRoot);
installPackages(discourseRoot);
buildBundle(discourseRoot);

const pluginDirs = [...CORE_PLUGINS.map((plugin) => join(discourseRoot, "plugins", plugin)), bbcodeRoot];
const plugins = pluginDirs.map(buildPlugin);
buildSettings(discourseRoot, pluginDirs);

writeFileSync(manifestPath, `${JSON.stringify({ ...wanted, plugins }, null, 2)}\n`);
console.log(`Built the engine in ${args.out}: ${plugins.join(", ")}`);
