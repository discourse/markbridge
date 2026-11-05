// Cooks Markdown with Discourse's own engine: the pretty-text bundle that
// build.mjs built, the markdown features of the plugins named, and the
// site setting defaults with the overrides given. Like the markdown-it
// cooker it reads one JSON request per line from stdin,
// {"id": 1, "markdown": "…"}, and writes {"id": 1, "html": "…"} per line.
//
//   node cook.mjs [--engine tmp/discourse_engine] [--plugins a,b,c]
//                 [--settings '{"discourse_post_event_enabled": true}']
//
// The bundle calls back into Ruby for a few things (PrettyText attaches
// them as `__Ruby`). Here they answer like a site with nothing in it: no
// users, no uploads, no translations. A mention still cooks to its span,
// an upload keeps its short URL in data-orig-src, like a post whose
// uploads are not there yet. Emoji stay off, they need the generated
// replacement table.

import { readFileSync } from "node:fs";
import { join } from "node:path";
import { createInterface } from "node:readline";
import { parseArgs } from "node:util";
import vm from "node:vm";

const { values: args } = parseArgs({
  options: {
    engine: { type: "string", default: "tmp/discourse_engine" },
    plugins: { type: "string", default: "" },
    settings: { type: "string", default: "{}" },
  },
});

// What PrettyText.create_es6_context sets up before the bundle loads.
globalThis.window = globalThis;
globalThis.devicePixelRatio = 2;
globalThis.__PRETTY_TEXT = true;
globalThis.__Ruby = {
  t: (key) => key,
  avatar_template: () => "",
  lookup_primary_user_group: () => null,
  format_username: (username) => username,
  lookup_upload_urls: () => ({}),
  get_topic_info: () => null,
  get_current_user: () => null,
  hashtag_lookup: () => null,
};

const load = (file) => vm.runInThisContext(readFileSync(file, "utf8"), { filename: file });

load(join(args.engine, "pretty-text.js"));
for (const plugin of args.plugins.split(",").filter(Boolean)) {
  load(join(args.engine, "plugins", `${plugin}.js`));
}

const siteSettings = {
  ...JSON.parse(readFileSync(join(args.engine, "settings.json"), "utf8")),
  enable_emoji: false,
  ...JSON.parse(args.settings),
};

// The options PrettyText.markdown builds per call; cook() adds its
// callbacks to them.
function cook(markdown) {
  return globalThis.__PrettyText.cook(markdown, {
    siteSettings,
    allowedIframes: [],
    paths: { baseUri: "" },
    customEmoji: {},
    customEmojiTranslation: {},
    emojiDenyList: [],
    censoredRegexp: [],
    watchedWordsReplace: null,
    watchedWordsLink: null,
    additionalOptions: {},
    avatar_sizes: siteSettings.avatar_sizes,
    hashtagTypesInPriorityOrder: ["category", "tag"],
    hashtagIcons: {},
  });
}

const lines = createInterface({ input: process.stdin, crlfDelay: Infinity });

for await (const line of lines) {
  const { id, markdown } = JSON.parse(line);
  process.stdout.write(`${JSON.stringify({ id, html: cook(markdown) })}\n`);
}
