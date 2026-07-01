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

<div class="format-tags">

### Inline formatting

| Wikitext | Renders as | AST node |
|---|---|---|
| `'''bold'''` | `**bold**` | `AST::Bold` |
| `''italic''` | `*italic*` | `AST::Italic` |
| `'''''both'''''` | `***both***` | `AST::Bold` + `AST::Italic` |
| `[[target]]` | `[target](target)` | `AST::Url` |
| `[[target\|display]]` | `[display](target)` | `AST::Url` |
| `[https://example.com text]` | `[text](href)` | `AST::Url` |

### Block syntax

| Wikitext | Renders as | AST node |
|---|---|---|
| `= H1 =` … `====== H6 ======` | `# H1` … `###### H6` | `AST::Heading` |
| `* item` / `** sub` | `- item` (nested) | `AST::List` |
| `# item` / `## sub` | `1. item` (nested) | `AST::List` |
| `----` | `---` | `AST::HorizontalRule` |
| Line starting with a space | Code block | `AST::Code` |
| `{\| ... \|}` | GFM table | `AST::Table` |

</div>

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
