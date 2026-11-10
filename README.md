# Markbridge

Markbridge converts BBCode, HTML, MediaWiki wikitext, and s9e/TextFormatter XML into Discourse-flavored Markdown through a clean parse → AST → render pipeline. It's built for forum migrations into Discourse, but works for any job that needs predictable, repeatable conversion.

Full documentation lives at **[markbridge.dev](https://markbridge.dev)**.

## How it works

Every conversion runs the same three steps:

1. **Parse** – a format-specific parser turns the input into an `AST::Document`. Unknown tags are counted, not raised — the parser keeps going.
2. **AST** – a renderer-agnostic tree of text, formatting, lists, links, and so on. The same tree comes out no matter which format went in.
3. **Render** – `Markbridge::Renderers::Discourse::Renderer` walks the tree and emits Discourse-compatible Markdown.

## Installation

Add the gem to your project:

```bash
bundle add markbridge
```

Or install it directly:

```bash
gem install markbridge
```

## Quick start

```ruby
require "markbridge/bbcode"

bbcode = "[b]Hello[/b] [url=https://example.com]world[/url]!"
result = Markbridge.bbcode_to_markdown(bbcode)

puts result.markdown
# => "**Hello** [world](https://example.com)!"
```

Swap `bbcode` for `html`, `mediawiki`, or `textformatter` for the other formats, or `require "markbridge/all"` to load everything.

`*_to_markdown` returns a `Markbridge::Conversion`, not a plain string. The rendered Markdown is on `.markdown` (and `.to_s` delegates to it, so `puts result` works). The same object also carries `.unknown_tags`, `.diagnostics`, and `.errors` — handy when you're migrating a forum and want to know what showed up.

## Customizing output

Build a renderer once with `Markbridge.discourse_renderer(...)` and pass it via `renderer:` — custom tags, a custom escaper, dropping tags, and more. See [Customizing the renderer](https://markbridge.dev/customization/customizing-renderer/), and [Migrating to Discourse](https://markbridge.dev/migrating/overview/) for the full forum-migration workflow.

## Learn more

* [markbridge.dev](https://markbridge.dev) – guides, format references, and the architecture deep-dive.
* `spec/` – executable documentation of every supported tag and edge case.
* `bin/console` – an interactive prompt for poking at things during development.

## Development

This repository is set up to run inside [silo](https://github.com/gschlager/silo), a development environment tool. The `.silo.yml` file provisions a Fedora container with CRuby, JRuby, TruffleRuby, Node.js, and pnpm. It installs dependencies and starts the playground on port 4567 and the docs site on port 4321. For a Ruby setup outside Silo, use `bin/setup` and `bundle install`. See [docs/README.md](docs/README.md) to run the documentation site.

## Playground

A local web UI to see what Markbridge makes of a piece of markup:

```bash
bin/playground
```

Open `http://127.0.0.1:4567`. The input is on the left, the output on the right, and the output follows while you type. Paste markup, drop a file on the input, or pick an example.

- **Formats**: BBCode, HTML, TextFormatter XML, MediaWiki. Every format keeps its own input, so a switch shows what that format had last. When your input looks like another format, the playground offers to read it with the other parser.
- **Output**: the Markdown, a preview, and the AST. The preview is cooked by Discourse's own engine when `bin/discourse-engine` has built it, otherwise by markdown-it (`npm ci --prefix spec/support/markdown_it`), which reads no BBCode.
- **Site**: the plugins of the target Discourse site (`spoiler-alert`, `discourse-bbcode`), which are the `features:` of the renderer, and a switch for the normalizer.
- **Notes**: unknown tags, tags the parser had to close and changes of the normalizer show up in the status bar.
- **Examples** (`Ctrl/Cmd+K`): searchable, also by a tag or a word in their input. The first one of every format, "Everything", shows every tag the parser knows; a spec checks it against the handler registries. An example has an address (`/bbcode/everything`), and "Copy link" makes one for your own input.

Keyboard: `Ctrl/Cmd+K` examples, `Alt+1` Markdown, `Alt+2` Preview, `Alt+3` AST.

To add an example, put a file into `playground/examples/<format>/` and list it in `playground/examples/catalog.yml`.
