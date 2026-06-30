---
title: Getting Started
description: Install Markbridge and run your first conversion in under five minutes.
---

This page takes you from install to a working conversion in about five minutes. For the big picture first — what Markbridge is and how it's put together — start with the [Introduction](/introduction/).

## Requirements

- Ruby 3.3 or newer (CRuby, or the latest TruffleRuby or JRuby)

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

Pick the method that matches your input:

| Method | Input format | Guide |
|---|---|---|
| `Markbridge.bbcode_to_markdown` | BBCode like `[b]...[/b]` | [BBCode](/format-guides/bbcode/) |
| `Markbridge.html_to_markdown` | HTML (via Nokogiri) | [HTML](/format-guides/html/) |
| `Markbridge.mediawiki_to_markdown` | MediaWiki wikitext | [MediaWiki](/format-guides/mediawiki/) |
| `Markbridge.text_formatter_xml_to_markdown` | <span class="nowrap">s9e/TextFormatter</span> XML (phpBB 3.2+) | [TextFormatter](/format-guides/textformatter/) |

`Markbridge.convert(input, format: :bbcode)` dispatches to the right one when the format isn't fixed at the call site (handy in migration loops that handle multiple formats).

Each `*_to_markdown` method has a matching `parse_*` method that returns a `Parse` (with the AST and unknown-tag data) instead of rendering — useful when you want to inspect, transform, or re-render with a custom renderer.

## Customizing output

Output is controlled by a `Renderer` instance, built once via `Markbridge.discourse_renderer(...)` and reused across calls:

```ruby
RENDERER = Markbridge.discourse_renderer(escape_hard_line_breaks: true)

result = Markbridge.bbcode_to_markdown("hi   \nthere", renderer: RENDERER)
```

See [Customizing the renderer](/customization/customizing-renderer/) for the full set of knobs (custom tags, dropping tags, custom escaper, postprocessor).

## Where to next

- **Converting your format?** See the [format guides](/format-guides/) for full tag coverage.
- **Customizing the output?** See [Customizing the renderer](/customization/customizing-renderer/).
- **Adding a tag the parser doesn't know?** See [Extending Markbridge](/customization/extending/).
- **Migrating a forum?** Start with [Migrating to Discourse](/migrating/overview/).
