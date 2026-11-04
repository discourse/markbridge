// Cooks Markdown with markdown-it, set up the way Discourse sets it up with
// its default site settings. The specs start it once and keep it running:
// it reads one JSON request per line from stdin, {"id": 1, "markdown": "…"},
// and writes one answer per line to stdout, {"id": 1, "html": "…"}.
//
// The options come from these Discourse files (the commit is in
// discourse.json, `node sync.mjs` updates it):
//
// - frontend/discourse-markdown-it/src/setup.js (#makeEngine)
//   html: true
//   breaks: !traditional_markdown_linebreaks
//   xhtmlOut: false
//   linkify: enable_markdown_linkify
//   typographer: enable_markdown_typographer
// - frontend/discourse-markdown-it/src/engine.js (makeEngine)
//   quotes: markdown_typographer_quotation_marks
//   linkify.tlds(markdown_linkify_tlds), linkify.set({ fuzzyLink: true })
//   mdurl.decode.defaultChars = ";/?:@&=+$,# " (setupUrlDecoding)
// - config/site_settings.yml for the defaults of these settings
//
// https://github.com/discourse/discourse/blob/main/frontend/discourse-markdown-it/src/setup.js
// https://github.com/discourse/discourse/blob/main/frontend/discourse-markdown-it/src/engine.js
//
// Discourse also replaces three rules. Two of them (newline, paragraph) only
// add a `leading_space` flag for oneboxes and render the same HTML. The third
// one (features/custom-typographer-replacements.js) has its own set of
// replacements. It is GPL code, so it is not copied here: markdown-it's own
// `replacements` rule is turned off instead, and only smartquotes is left of
// the typographer. Everything else Discourse adds (BBCode, mentions, emoji,
// upload://, image options, the sanitizer) is missing as well.

import { readFileSync } from "node:fs";
import { createInterface } from "node:readline";
import markdownit from "markdown-it";

const discourse = JSON.parse(
  readFileSync(new URL("discourse.json", import.meta.url), "utf8")
);
const settings = discourse.site_settings;

const md = markdownit({
  html: true,
  breaks: !settings.traditional_markdown_linebreaks,
  xhtmlOut: false,
  linkify: settings.enable_markdown_linkify,
  typographer: settings.enable_markdown_typographer,
});

md.options.quotes = settings.markdown_typographer_quotation_marks.split("|");
md.linkify.tlds(settings.markdown_linkify_tlds.split("|"));
md.linkify.set({ fuzzyLink: true });
md.utils.lib.mdurl.decode.defaultChars = ";/?:@&=+$,# ";
md.disable("replacements");

const lines = createInterface({ input: process.stdin, crlfDelay: Infinity });

for await (const line of lines) {
  const { id, markdown } = JSON.parse(line);
  process.stdout.write(`${JSON.stringify({ id, html: md.render(markdown) })}\n`);
}
