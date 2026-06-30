---
title: Getting Started
description: Install Markbridge and run your first conversion in under five minutes.
---

Markbridge converts markup to Discourse-flavored Markdown through a parse → AST → render pipeline. This page takes you from install to a working conversion — give it five minutes.

## Requirements

- Ruby 3.3 or newer (CRuby, or the latest TruffleRuby or JRuby)
- Bundler

## Install

Add to your `Gemfile`:

```bash
bundle add markbridge
```

Or install it directly:

```bash
gem install markbridge
```

## Your first conversion

```ruby
require "markbridge/bbcode"

bbcode = "[b]Hello[/b] [url=https://example.com]world[/url]!"
result = Markbridge.bbcode_to_markdown(bbcode)
puts result.markdown
# => **Hello** [world](https://example.com)!
```

`require "markbridge/bbcode"` loads the BBCode parser plus the Discourse renderer. Swap `bbcode` for `html`, `mediawiki`, or `textformatter` for the other formats, or use `markbridge/all` to load all four at once. HTML and TextFormatter pull in Nokogiri; BBCode and MediaWiki don't.

`*_to_markdown` returns a `Markbridge::Conversion` value object, not a plain string. The rendered Markdown is on `.markdown`; `.to_s` delegates to it so `puts result` and string interpolation `"#{result}"` work. The Conversion also carries `.unknown_tags`, `.diagnostics`, and `.errors` — see [Migrating to Discourse → Overview](/migrating/overview/) for what they're for.

## The four formats

Markbridge ships with four parsers that all feed the same Markdown renderer. Pick the one that matches your input:

| Method | Input format | Guide |
|---|---|---|
| `Markbridge.bbcode_to_markdown` | BBCode like `[b]...[/b]` | [BBCode → Markdown](/format-guides/bbcode/) |
| `Markbridge.html_to_markdown` | HTML (via Nokogiri) | [HTML → Markdown](/format-guides/html/) |
| `Markbridge.mediawiki_to_markdown` | MediaWiki wikitext | [MediaWiki → Markdown](/format-guides/mediawiki/) |
| `Markbridge.text_formatter_xml_to_markdown` | <span class="nowrap">s9e/TextFormatter</span> XML (phpBB 3.2+) | [TextFormatter → Markdown](/format-guides/textformatter/) |

`Markbridge.convert(input, format: :bbcode)` dispatches to the right one when the format isn't fixed at the call site (handy in migration loops that handle multiple formats).

Each `*_to_markdown` method has a matching `parse_*` method that returns a `Parse` (with the AST and unknown-tag data) instead of rendering — useful when you want to inspect, transform, or re-render with a custom renderer.

## What just happened

Under the hood, every conversion runs three phases:

1. **Parse** — a format-specific parser tokenizes the input and builds an `AST::Document`.
2. **Transform** — the AST is a renderer-agnostic tree of `Text`, `Element`, and leaf nodes.
3. **Render** — `Markbridge::Renderers::Discourse::Renderer` walks the tree and emits Markdown.

Read [Architecture](/concepts/architecture/) for a deeper tour, or jump straight into [Extending Markbridge](/customization/extending/) if you already know you need a custom tag.

## Customizing output

Output is controlled by a `Renderer` instance, built once via `Markbridge.discourse_renderer(...)` and reused across calls:

```ruby
RENDERER = Markbridge.discourse_renderer(escape_hard_line_breaks: true)

result = Markbridge.bbcode_to_markdown("hi   \nthere", renderer: RENDERER)
```

See [Customizing the renderer](/customization/customizing-renderer/) for the full set of knobs (custom tags, dropping tags, custom escaper, postprocessor).

## Where to next

- **Migrating a forum to Discourse?** Start with [Migrating to Discourse → Overview](/migrating/overview/).
- **Converting** a specific format? Jump to the matching [format guide](/format-guides/bbcode/).
- **Adding** a new tag? See [Extending Markbridge](/customization/extending/).
- **Understanding** how the pipeline works? Start with [Architecture](/concepts/architecture/).
- **Optimizing**? See [Performance](/concepts/performance/).
