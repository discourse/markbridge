---
title: MediaWiki
description: Convert MediaWiki wikitext into Discourse-flavored Markdown.
---

Use the MediaWiki parser for the wikitext of a wiki: the source of a page as an editor sees it, or the `<text>` of an XML export. It reads the markup that makes up most pages: formatting, headings, lists, links, files, tables, and the HTML tags wikitext allows. It does not expand templates, see [Limits](#limits).

## Quick start

```ruby
require "markbridge/mediawiki"

result = Markbridge.mediawiki_to_markdown("'''bold''' and ''italic''")
result.markdown
# => "**bold** and *italic*"
```

`result` is a [`Markbridge::Conversion`](/concepts/result-objects/). Next to `markdown` it has the AST and `unknown_tags`.

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

Wikitext allows some HTML tags. The parser reads these, in any case (`<S>` like `<s>`):

| Tag | Renders as |
|---|---|
| `<nowiki>` | Its content as text, with the wiki markup in it left alone. It can go over several lines |
| `<code>` | A code span; a fenced code block when the content has a line break |
| `<pre>` | A fenced code block, also for one line; a code span inside a line of text |
| `<br>` | A line break |
| `<s>` | `~~strike~~` |
| `<u>` | `[u]underline[/u]` |
| `<sup>`, `<sub>` | `<sup>…</sup>`, `<sub>…</sub>` |
| `<ins>`, `<del>`, `<mark>` | The same HTML tags, which Discourse keeps |

Any other tag stays in the output as text, and `unknown_tags` counts it.

## Links to wiki pages

A link like `[[Main Page]]` names a page, not an address. The parser gives it an address relative to the wiki, the same one MediaWiki writes into its HTML: `./Main_Page`, with underscores for the spaces.

- A namespace and a section stay in the address: `[[Help:Contents#Hiking]]` is `./Help:Contents#Hiking`.
- A link to a section of the same page keeps its target: `[[#History]]` is `#History`.

A relative address is of no use in Discourse, which drops an address without a scheme and without a leading slash and shows the link as text. Give the renderer the address of the wiki as `base_url:`, and the links point to the wiki:

```ruby
renderer = Markbridge.discourse_renderer(base_url: "https://wiki.example.com/wiki/")

wikitext = "See the [[Main Page]] and [[Help:Contents|the help]]."
Markbridge.mediawiki_to_markdown(wikitext, renderer:).markdown
# => "See the [Main Page](https://wiki.example.com/wiki/Main_Page) and [the help](https://wiki.example.com/wiki/Help:Contents)."
```

The base URL is the address in front of a page title. For most wikis that is `https://…/wiki/`, with the slash at the end. See [Customizing the renderer](/customization/customizing-renderer/#base_url--where-relative-addresses-point-to).

Some pages may move to Discourse with the content, and their links should point to the new topics. Change those links on the AST before rendering. Every page link starts with `./`, so they are easy to find.

## Files and categories

`[[File:Sunrise.jpg|thumb|200px|A sunrise]]` embeds a file. What it becomes depends on the file:

- **An image** (`.png`, `.jpg`, `.gif`, `.svg`, `.webp`, …) is an `AST::Image`. Its address is `./Special:FilePath/Sunrise.jpg`, the page a wiki answers with the file itself. Like a page link it needs `base_url:` to work in Discourse.
- **Any other file** is a link to its page, `./File:Track.gpx`, with the caption or the file name as its text.

The caption is the alternative text of the image, or `alt=…` when the embed has one. A size with a width and a height, `200x100px`, is kept. A width alone is dropped, because Discourse has no form for it. The options for the frame and the alignment (`thumb`, `right`, `border`, …) are dropped, Markdown has no form for them. `[[Image:…]]` is the old name of the same thing.

`[[Category:Hiking]]` puts a page into a category and shows nothing in the text, so the parser drops it. With a colon in front, `[[:Category:Hiking]]`, it is a normal link to the category page, and `[[:File:Sunrise.jpg]]` is one to the file page.

## Using the parser directly

```ruby
parser = Markbridge::Parsers::MediaWiki::Parser.new
ast = parser.parse("== Section ==\n* one\n* two")

renderer = Markbridge::Renderers::Discourse::Renderer.new
renderer.render(ast)
# => "## Section\n\n- one\n- two"
```

Calling the renderer yourself skips normalizing and the final cleanup of the output. `Markbridge.render(Markbridge.parse_mediawiki(input))` does both.

## Customizing

The block syntax of wikitext is fixed, so there are no handlers for headings, lists or tables. What you can register are HTML-like tags, in an `InlineTagRegistry` that you pass as `handlers:`:

<!-- spec:before
MyCustomNode = Class.new(Markbridge::AST::Element)
input = "hello world"
-->
```ruby
registry = Markbridge::Parsers::MediaWiki::InlineTagRegistry.default
registry.register("custom", :raw, MyCustomNode)

Markbridge.mediawiki_to_markdown(input, handlers: registry)
```

The second argument says what the tag does with its content:

- `:raw` keeps the content as it is and does not parse it.
- `:formatting` parses the content as wikitext.
- `:self_closing` is a tag without content.

For anything else, change the AST after parsing, or register another renderer tag with [`Markbridge.discourse_renderer(tags:)`](/customization/customizing-renderer/).

## Limits

The parser reads wikitext, it does not run a wiki. What a wiki computes when it shows a page is missing:

- **Templates.** `{{Infobox …}}` or `{{cite web|…}}` are text in the output, with their braces. Expanding one needs the template's page and the parser functions of MediaWiki.
- **Magic words and parser functions** (`__NOTOC__`, `{{PAGENAME}}`, `{{#if:…}}`) are text too.
- **References.** `<ref>` and `<references/>` are text, like every tag the parser does not know. No footnotes are built.
- **Files and images are not copied.** They keep pointing to the wiki.
- **Categories** are not turned into tags or categories of Discourse.

When your pages depend on templates, the wiki itself is the better source: its API returns the HTML of a page with every template expanded (`action=parse`), and the [HTML parser](/format-guides/html/) reads that.
