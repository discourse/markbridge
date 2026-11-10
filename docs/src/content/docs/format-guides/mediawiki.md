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
| `[[Page title]]` | `[Page title](./Page_title)` | `AST::Url` |
| `[[Page title\|display]]` | `[display](./Page_title)` | `AST::Url` |
| `[https://example.com text]` | `[text](href)` | `AST::Url` |
| `[[File:Name.jpg\|thumb\|Caption]]` | `![Caption](./Special:FilePath/Name.jpg)` | `AST::Image` |
| `[[Category:Name]]` | Nothing | — |

### Block syntax

| Wikitext | Renders as | AST node |
|---|---|---|
| `= H1 =` … `====== H6 ======` | `# H1` … `###### H6` | `AST::Heading` |
| `* item` / `** sub` | `- item` (nested) | `AST::List` |
| `# item` / `## sub` | `1. item` (nested) | `AST::List` |
| `----` | `---` | `AST::HorizontalRule` |
| Line starting with a space | Code block | `AST::Code` |
| `{\| ... \|}` | GFM table, or an HTML table when Markdown cannot express it (a `colspan` or `rowspan`, uneven rows, a block in a cell) | `AST::Table` |

</div>

### HTML tags

MediaWiki accepts a small set of inline HTML. Markbridge honors:

`<nowiki>`, `<code>`, `<pre>`, `<br>`, `<s>`, `<del>`, `<u>`, `<ins>`, `<mark>`, `<sup>`, `<sub>`.

`<ins>`, `<del>` and `<mark>` are written as the same HTML tags, which Discourse keeps.

Inside `<nowiki>`, wiki syntax is preserved as literal text. The tag can go over several lines. The tags are read in any case, `<S>` like `<s>`. Indented code and `<pre>` content render as fenced code blocks, even for a single line. `<code>` stays inline unless its content contains a newline.

## Links to wiki pages

A link to a page, `[[Main Page]]`, has an href relative to the wiki, in the form MediaWiki's own HTML has: `./Main_Page`, with underscores for the spaces of the title. A namespace and a section stay in it (`[[Help:Contents#Hiking]]` is `./Help:Contents#Hiking`), and a link to a section of the same page keeps its target (`[[#History]]` is `#History`).

Discourse drops the address of a link that has no scheme and no leading slash, so such a link shows as text there. Give the renderer the address of the wiki as `base_url:`, and the page links point to it:

```ruby
renderer = Markbridge.discourse_renderer(base_url: "https://wiki.example.com/wiki/")

wikitext = "See the [[Main Page]] and [[Help:Contents|the help]]."
Markbridge.mediawiki_to_markdown(wikitext, renderer:).markdown
# => "See the [Main Page](https://wiki.example.com/wiki/Main_Page) and [the help](https://wiki.example.com/wiki/Help:Contents)."
```

To send some pages somewhere else, to a topic in Discourse for example, change the links on the AST before rendering. Every page link starts with `./`, so they are easy to find. See [Customizing the renderer](/customization/customizing-renderer/#base_url--where-relative-addresses-point-to) for `base_url:`.

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
- **Files** keep their address on the wiki. An image is an image at `Special:FilePath`, the page a wiki answers with the file itself, so it needs `base_url:` to show. The caption is its alternative text, the frame and alignment options are dropped. Any other file is a link to its page.
- **Categories** show nothing, like on the wiki. They are not turned into tags or categories of Discourse.
- **Reference footnotes** (`<ref>`) are not special-cased.

If your export relies on these, pre-process before handing it to Markbridge, or post-process the AST.
