---
title: Get started
description: Install Markbridge, convert your first document, and read the result.
---

This page takes you from an empty Gemfile to converted Markdown. The [Introduction](/introduction/) explains what happens inside.

## Requirements

Ruby 3.3 or newer. Markbridge runs on CRuby, JRuby, and TruffleRuby.

## Install

```bash
bundle add markbridge
```

The HTML and TextFormatter parsers need Nokogiri. Markbridge does not install it for you, because BBCode and MediaWiki work without it:

```bash
bundle add nokogiri
```

## Your first conversion

```ruby
require "markbridge/bbcode"

bbcode = "[b]Hello[/b] [url=https://example.com]world[/url]!"
result = Markbridge.bbcode_to_markdown(bbcode)
puts result.markdown
# => **Hello** [world](https://example.com)!
```

`require "markbridge/bbcode"` loads the BBCode parser and the Discourse renderer. The other formats load the same way: `markbridge/html`, `markbridge/mediawiki`, `markbridge/textformatter`. `markbridge/all` loads all four.

The result is a `Markbridge::Conversion`, not a String. The Markdown is in `result.markdown`, and `puts result` and `"#{result}"` print it too. The same object has the tags the parser did not know (`unknown_tags`), notes from the parser (`diagnostics`) and render errors (`errors`). See [Result objects](/concepts/result-objects/).

## The four formats

| Method | Input | Guide |
|---|---|---|
| `Markbridge.bbcode_to_markdown` | BBCode like `[b]…[/b]` | [BBCode](/format-guides/bbcode/) |
| `Markbridge.html_to_markdown` | HTML | [HTML](/format-guides/html/) |
| `Markbridge.mediawiki_to_markdown` | MediaWiki wikitext | [MediaWiki](/format-guides/mediawiki/) |
| `Markbridge.text_formatter_xml_to_markdown` | <span class="nowrap">s9e\TextFormatter</span> XML (phpBB 3.2+, Flarum) | [TextFormatter](/format-guides/textformatter/) |

When the format is only known at run time, use `Markbridge.convert(input, format: :bbcode)`. The formats are `:bbcode`, `:html`, `:mediawiki` and `:text_formatter_xml`.

Every `*_to_markdown` method has a `parse_*` method next to it (`parse_bbcode`, `parse_html`, …). It stops after parsing and returns a `Parse` with the AST. Use it to look at the tree, to change it, or to render it with your own renderer.

## Change the output

A `Renderer` decides how the tree is written. Build one with `Markbridge.discourse_renderer` and pass it to every call:

```ruby
RENDERER = Markbridge.discourse_renderer(base_url: "https://old.example.com/forum/")

result = Markbridge.bbcode_to_markdown("[url=viewtopic.php?t=34]an older topic[/url]", renderer: RENDERER)
result.markdown
# => "[an older topic](https://old.example.com/forum/viewtopic.php?t=34)"
```

[Customizing the renderer](/customization/customizing-renderer/) lists all options: your own tags, the plugins of the target site, relative links, escaping.

## Next steps

- **Your format in detail:** the [format guides](/format-guides/) list every tag.
- **A tag the parser does not know:** [Extending Markbridge](/customization/extending/).
- **A forum migration:** [Migrating to Discourse](/migrating/overview/).
- **Try it in the browser:** clone the repository and run `bin/playground`.
