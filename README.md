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
* `examples/` – runnable scripts, from `basic_usage.rb` to a full `forum_migration.rb`.
* `spec/` – executable documentation of every supported tag and edge case.
* `bin/console` – an interactive prompt for poking at things during development.

## Development

This repository is set up to run inside [silo](https://github.com/gschlager/silo), a lightweight dev-environment tool. The `.silo.yml` file provisions a Fedora container with JRuby and multiple CRuby versions (via [rv](https://rv.dev)), installs dependencies, and starts the playground daemon. If you prefer your own setup, `bin/setup` and `bundle install` are all you need.

## Playground

A local web UI for exploring parsers interactively:

```bash
bin/playground
```

Open `http://127.0.0.1:4567` to select a parser (BBCode, HTML, TextFormatter XML, MediaWiki), pick an example, edit the input, and inspect the AST tree and Markdown output. Keyboard shortcuts: `1` Input, `2` Output, `3` AST, `Cmd/Ctrl+Enter` to render.
