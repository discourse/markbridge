---
title: Getting Started
description: Install Markbridge and run your first conversion in under five minutes.
---

Markbridge converts markup to Discourse-flavored Markdown through a parse → AST → render pipeline. This page takes you from install to a working conversion.

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
puts Markbridge.bbcode_to_markdown(bbcode)
# => **Hello** [world](https://example.com)!
```

`require "markbridge/bbcode"` loads the BBCode parser plus the Discourse renderer. Swap `bbcode` for `html`, `mediawiki`, or `textformatter` for the other formats, or use `markbridge/all` to load all four at once. HTML and TextFormatter pull in Nokogiri; BBCode and MediaWiki don't.

## The four formats

Markbridge ships with four parsers that all feed the same Markdown renderer. Pick the one that matches your input:

| Method | Input format | Guide |
|---|---|---|
| `Markbridge.bbcode_to_markdown` | BBCode like `[b]...[/b]` | [BBCode → Markdown](/guides/bbcode/) |
| `Markbridge.html_to_markdown` | HTML (via Nokogiri) | [HTML → Markdown](/guides/html/) |
| `Markbridge.mediawiki_to_markdown` | MediaWiki wikitext | [MediaWiki → Markdown](/guides/mediawiki/) |
| `Markbridge.text_formatter_xml_to_markdown` | <span class="nowrap">s9e/TextFormatter</span> XML (phpBB 3.2+) | [TextFormatter → Markdown](/guides/textformatter/) |

Each `*_to_markdown` method has a matching `parse_*` method that returns the AST instead of rendering it, useful when you want to inspect, transform, or re-render with a custom tag library.

## What just happened

Under the hood, every conversion runs three phases:

1. **Parse** — a format-specific parser tokenizes the input and builds an `AST::Document`.
2. **Transform** — the AST is a renderer-agnostic tree of `Text`, `Element`, and leaf nodes.
3. **Render** — `Markbridge::Renderers::Discourse::Renderer` walks the tree and emits Markdown.

Read [Architecture](/concepts/architecture/) for a deeper tour, or jump straight into [Extending Markbridge](/guides/extending/) if you already know you need a custom tag.

## Configuration

A small global configuration object controls output behavior:

```ruby
Markbridge.configure do |config|
  # Strip trailing spaces before newlines (which would become <br/> in Markdown).
  # Default: false — matches Discourse defaults.
  config.escape_hard_line_breaks = true
end
```

See [Configuration](/guides/configuration/) for the full list.

## Where to next

- **Converting** something specific? Jump to the matching guide under [Guides](/guides/bbcode/).
- **Adding** a new tag or customizing output? See [Extending Markbridge](/guides/extending/).
- **Understanding** how the pipeline works? Start with [Architecture](/concepts/architecture/).
- **Optimizing**? See [Performance](/concepts/performance/).
