---
title: MediaWiki
description: Convert MediaWiki wikitext into Discourse-flavored Markdown.
---

The MediaWiki parser handles the wikitext subset most commonly found in wiki exports — formatting, lists, headings, links, tables, and the HTML tags MediaWiki accepts inline.

## Quick start

```ruby
require "markbridge/mediawiki"

result = Markbridge.mediawiki_to_markdown("'''bold''' and ''italic''")
result.markdown
# => "**bold** and *italic*"
```

Like the other parsers, the convenience method returns a [`Markbridge::Conversion`](/concepts/result-objects/).

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

MediaWiki's block syntax is fixed — there's no handler registry for headings, lists, tables, etc. Inline HTML-like tags (`<nowiki>`, `<code>`, `<sup>`, etc.) go through an `InlineTagRegistry` you can customize via the `handlers:` kwarg:

<!-- spec:before
MyCustomNode = Class.new(Markbridge::AST::Element)
input = "hello world"
-->
```ruby
registry = Markbridge::Parsers::MediaWiki::InlineTagRegistry.default
registry.register("custom", :raw, MyCustomNode)

Markbridge.mediawiki_to_markdown(input, handlers: registry)
```

`type` is one of `:raw` (content preserved verbatim, not re-parsed), `:formatting` (content re-parsed), or `:self_closing` (leaf with no content).

For block-level customization, transform the AST after parsing, or register a different renderer tag via [`Markbridge.discourse_renderer(tags:)`](/customization/customizing-renderer/).

## Limitations

The parser targets the bulk of content you'll see in wiki exports, not the full MediaWiki specification:

- **No templates** (`{{Template}}`). They're passed through as literal text.
- **No magic words or parser functions** (`__NOTOC__`, `{{#if:}}`, etc.).
- **Categories and file embeds** are not translated to Discourse equivalents.
- **Reference footnotes** (`<ref>`) are not special-cased.

If your export relies on these, pre-process before handing it to Markbridge, or post-process the AST.
