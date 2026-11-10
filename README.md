# Markbridge

Markbridge is a Ruby library that converts BBCode, HTML, MediaWiki wikitext, and s9e\TextFormatter XML to Markdown. It parses the input into a tree, so you can look at the content and change it before it is written. The renderer that ships with it writes Markdown for [Discourse](https://www.discourse.org), and migrating a forum to Discourse is what it is used for most.

The documentation is at **[markbridge.dev](https://markbridge.dev)**.

## How it works

Every conversion has three steps:

1. **Parse.** A parser for the input format builds a tree, the AST. It does not raise on bad markup. Tags it does not know are counted.
2. **Normalize.** Markup can nest what Markdown cannot, like a link inside a link. This step rewrites those parts of the tree.
3. **Render.** The renderer walks the tree and writes Markdown.

The AST has the same node types for every input format, and it does not depend on the renderer.

## Installation

```bash
bundle add markbridge
```

The HTML and TextFormatter parsers also need Nokogiri (`bundle add nokogiri`). Markbridge needs Ruby 3.3 or newer and runs on CRuby, JRuby and TruffleRuby.

## Quick start

```ruby
require "markbridge/bbcode"

bbcode = "[b]Hello[/b] [url=https://example.com]world[/url]!"
result = Markbridge.bbcode_to_markdown(bbcode)

puts result.markdown
# => **Hello** [world](https://example.com)!
```

The other formats work the same way: `require "markbridge/html"` and `Markbridge.html_to_markdown`, `markbridge/mediawiki` and `mediawiki_to_markdown`, `markbridge/textformatter` and `text_formatter_xml_to_markdown`. `require "markbridge/all"` loads all four.

The result is a `Markbridge::Conversion`, not a String. Next to `markdown` it has the tree (`ast`), the tags the parser did not know (`unknown_tags`), what the parser had to repair (`diagnostics`) and render errors (`errors`).

## Change the output

Build a renderer with `Markbridge.discourse_renderer` and pass it to every call:

```ruby
RENDERER = Markbridge.discourse_renderer(
  features: { bbcode: false },                  # the target site has no discourse-bbcode plugin
  base_url: "https://old.example.com/forum/",   # makes relative links and images absolute
)

Markbridge.bbcode_to_markdown(bbcode, renderer: RENDERER)
```

[Customizing the renderer](https://markbridge.dev/customization/customizing-renderer/) lists the options. For tags only your forum has, see [Extending Markbridge](https://markbridge.dev/customization/extending/). For a forum migration, start with [Migrating to Discourse](https://markbridge.dev/migrating/overview/).

## Learn more

* [markbridge.dev](https://markbridge.dev) has the guides for every format and explains how the parts work.
* `spec/` has a test for every supported tag and many edge cases.
* `bin/console` starts IRB with Markbridge loaded.
* `bin/playground` starts a web UI to try input in the browser, see below.

## Development

This repository is set up to run inside [silo](https://github.com/gschlager/silo), a development environment tool. The `.silo.yml` file provisions a Fedora container with CRuby, JRuby, TruffleRuby, Node.js, and pnpm. It installs dependencies and starts the playground on port 4567 and the docs site on port 4321. For a Ruby setup outside Silo, use `bin/setup` and `bundle install`. See [docs/README.md](docs/README.md) to run the documentation site.

## Playground

A local web UI to see what Markbridge makes of a piece of markup:

```bash
bin/playground
```

Open `http://127.0.0.1:4567`. The input is on the left, with its tags in color, the output on the right, and the output follows while you type. Paste markup, drop a file on the input, or pick an example.

- **Formats**: BBCode, HTML, TextFormatter XML, MediaWiki. Every format keeps its own input, so a switch shows what that format had last. When your input looks like another format, the playground offers to read it with the other parser.
- **Output**: the Markdown, a preview, and the AST. The preview is cooked by Discourse's own engine when `bin/discourse-engine` has built it, otherwise by markdown-it (`npm ci --prefix spec/support/markdown_it`), which reads no BBCode.
- **Site**: the plugins of the target Discourse site (`spoiler-alert`, `discourse-bbcode`), which are the `features:` of the renderer, a base URL for relative links and images, and a switch for the normalizer.
- **Notes**: unknown tags, tags the parser had to close and changes of the normalizer show up in the status bar.
- **Examples** (`Ctrl/Cmd+K`): searchable, also by a tag or a word in their input. The first one of every format, "Everything", shows every tag the parser knows; a spec checks it against the handler registries. An example has an address (`/bbcode/everything`), and "Copy link" makes one for your own input.

Keyboard: `Ctrl/Cmd+K` examples, `Alt+1` Markdown, `Alt+2` Preview, `Alt+3` AST.

To add an example, put a file into `playground/examples/<format>/` and list it in `playground/examples/catalog.yml`.
