---
title: MediaWiki → Markdown
description: Convert MediaWiki wikitext into Discourse-flavored Markdown.
---

The MediaWiki parser handles the wikitext subset most commonly found in wiki exports — formatting, lists, headings, links, tables, and the HTML tags MediaWiki accepts inline.

## Quick start

```ruby
require "markbridge/all"

Markbridge.mediawiki_to_markdown("'''bold''' and ''italic''")
# => "**bold** and *italic*"
```

## Supported syntax

### Inline formatting

| Wikitext | Output |
|---|---|
| `'''bold'''` | `**bold**` |
| `''italic''` | `*italic*` |
| `'''''both'''''` | `***both***` |
| `[[target]]` | Internal link with `target` as both href and text |
| `[[target\|display]]` | Internal link with custom display text |
| `[https://example.com text]` | External link |

### Block syntax

| Wikitext | Output |
|---|---|
| `= H1 =` through `====== H6 ======` | Headings |
| `* item` / `** sub` / `*** deep` | Nested unordered list |
| `# item` / `## sub` | Nested ordered list |
| `----` | Horizontal rule |
| Line starting with a space | Preformatted block |
| `{\| ... \|}` | Table |

### HTML tags

MediaWiki accepts a small set of inline HTML. Markbridge honors:

`<nowiki>`, `<code>`, `<pre>`, `<br>`, `<s>`, `<del>`, `<u>`, `<ins>`, `<sup>`, `<sub>`.

Inside `<nowiki>`, wiki syntax is preserved as literal text.

## Using the parser directly

```ruby
parser = Markbridge::Parsers::MediaWiki::Parser.new
ast = parser.parse("== Section ==\n* one\n* two")

renderer = Markbridge::Renderers::Discourse::Renderer.new
renderer.render(ast)
# => "## Section\n\n- one\n- two"
```

Unlike BBCode and HTML, the MediaWiki parser has no handler registry — it's a fixed-syntax parser. If you need to customize the output for a specific wikitext element, transform the AST after parsing or register a different renderer tag.

## Limitations

The parser targets the bulk of content you'll see in wiki exports, not the full MediaWiki specification:

- **No templates** (`{{Template}}`). They're passed through as literal text.
- **No magic words or parser functions** (`__NOTOC__`, `{{#if:}}`, etc.).
- **Categories and file embeds** are not translated to Discourse equivalents.
- **Reference footnotes** (`<ref>`) are not special-cased.

If your export relies on these, pre-process before handing it to Markbridge, or post-process the AST.
