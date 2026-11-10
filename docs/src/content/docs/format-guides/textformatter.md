---
title: TextFormatter
description: Convert s9e/TextFormatter XML (used by phpBB 3.2+) into Discourse-flavored Markdown.
---

The TextFormatter parser reads the XML format produced by <a href="https://github.com/s9e/TextFormatter" class="nowrap">s9e/TextFormatter</a>, the library phpBB 3.2+ uses to store parsed BBCode. Converting the stored XML directly is faster and more faithful than re-parsing the original BBCode.

## Requirements

Add `nokogiri` to your Gemfile. It's a runtime dependency for the TextFormatter parser:

```ruby
gem "nokogiri"
```

## Quick start

```ruby
require "markbridge/textformatter"

xml = "<r><B><s>[b]</s>Hello<e>[/b]</e></B> world!</r>"
result = Markbridge.text_formatter_xml_to_markdown(xml)
result.markdown
# => "**Hello** world!"
```

## The s9e format in brief

TextFormatter wraps content in one of two roots:

- `<t>` — plain text (no BBCode was used).
- `<r>` — rich text (contains formatted elements).

Inside `<r>`, formatted children use **uppercase element names** by convention (`<B>`, `<URL>`, `<CODE>`). Each formatted element may wrap its original BBCode markup in `<s>` (start) and `<e>` (end) tags — Markbridge ignores these during parsing. It also ignores `<i>` (lowercase), which holds text that s9e did not use, like the newline after `[list]` or a `[/b]` without a matching `[b]`. `<I>` (uppercase) is italic.

A line break is stored as `<br/>` followed by a newline in the next text node (`a<br/>\nb`). Forums render the XML as HTML, so that newline and any spaces at the start of a line are not visible. Markbridge removes them outside of `<CODE>`, so `a<br/>\nb` becomes `a\nb` and indented lines don't turn into code blocks. Two `<br/>` become a blank line. Text inside `<CODE>` stays as it is.

## Supported elements

<div class="format-tags">

| Element | Renders as | AST node |
|---|---|---|
| `<B>` | `**bold**` | `AST::Bold` |
| `<I>` | `*italic*` | `AST::Italic` |
| `<S>` | `~~strike~~` | `AST::Strikethrough` |
| `<U>` | `<u>underline</u>` | `AST::Underline` |
| `<CODE>` | Fenced code block, including single-line content | `AST::Code` |
| `<URL>` | `[text](href)` | `AST::Url` |
| `<EMAIL>` | `[text](mailto:addr)` | `AST::Url` |
| `<IMG>` | `![](src)` | `AST::Image` |
| `<ATTACHMENT>` | Discourse upload syntax | `AST::Attachment` |
| `<QUOTE>` | `[quote="name"]…[/quote]`; without attribution `> …`, or `[quote]…[/quote]` around a quote with attribution | `AST::Quote` |
| `<LIST>` | `- item` / `1. item` | `AST::List` |
| `<LI>` | List item | `AST::ListItem` |
| `<TABLE>`, `<TR>`, `<TD>`, `<TH>` | GFM table | `AST::Table` |
| `<COLOR>`, `<SIZE>` | See [Colors and sizes](#colors-and-sizes) | `AST::Color`, `AST::Size` |
| `<ALIGN>`, `<CENTER>` | `<div align="…">` | `AST::Align` |
| `<SPOILER>` | Block spoiler: `[spoiler]` and `[/spoiler]` on lines of their own, a title as a paragraph in front | `AST::Spoiler` with `block: true` |
| `<ISPOILER>` | `[spoiler]…[/spoiler]` inside the line | `AST::Spoiler` |
| `<HR>` | `---` | `AST::HorizontalRule` |
| `<br/>` | Hard line break | `AST::LineBreak` |

</div>

### Litedown

Litedown is the Markdown plugin of s9e. Flarum stores its posts with it, and it has elements of its own next to the BBCode ones:

| Element | Markdown source | Renders as | AST node |
|---|---|---|---|
| `<STRONG>` | `**bold**` | `**bold**` | `AST::Bold` |
| `<EM>` | `*italic*` | `*italic*` | `AST::Italic` |
| `<DEL>` | `~~strike~~` | `~~strike~~` | `AST::Strikethrough` |
| `<SUP>`, `<SUB>` | `x^2^`, `H~2~O` | `<sup>…</sup>` / `<sub>…</sub>` | `AST::Superscript`, `AST::Subscript` |
| `<C>` | `` `code` `` | Code span | `AST::Code` |
| `<CODE>` | Fenced or indented code | Fenced code block | `AST::Code` with `block: true` |
| `<H1>`–`<H6>` | `# Heading` or an underlined one | `#` through `######` headings | `AST::Heading` |
| `<ISPOILER>` | `\|\|spoiler\|\|` | `[spoiler]…[/spoiler]` inside the line | `AST::Spoiler` |
| `<SPOILER>` | `>! spoiler` | Block spoiler | `AST::Spoiler` with `block: true` |
| `<p>` | A paragraph | Paragraph spacing | `AST::Paragraph` |

`<QUOTE>`, `<LIST>`, `<LI>`, `<URL>`, `<EMAIL>`, `<IMG>` and `<HR>` are the same elements as for BBCode. The markers of the Markdown source sit in `<s>`, `<e>` and `<i>` elements, which the parser skips like the BBCode tags there.

Flarum's own elements, for example the mentions of users and posts, have no handler. Register one for the ones your forum uses, see [Extending Markbridge](/customization/extending/).

### Notes on the elements

phpBB shows a `[spoiler]` as a block, so `<SPOILER>` is a block spoiler and the text after it starts a new line. `<ISPOILER>` is the inline spoiler of the Litedown plugin. `<HR>` comes from the `[hr]` BBCode of the s9e repository and from Litedown.

Several elements carry attributes Markbridge reads: `<CODE>` (`lang`), `<URL>` (`url`), `<EMAIL>` (`email`), `<IMG>` (`src`), `<LIST>` (`type` — `bullet` or `decimal`), and `<QUOTE>` (attribution).

For the exact list, see [`HandlerRegistry.default`](https://github.com/discourse/markbridge/blob/main/lib/markbridge/parsers/text_formatter/handler_registry.rb).

## Colors and sizes

Discourse core removes the style of a `<span>`, so what to do with `<COLOR>` and `<SIZE>` depends on the site: build the renderer with `features: { bbcode: false }` to write their text, or with `features: { bbcode: true }` for a site with the discourse-bbcode plugin, which keeps them as `[color=…]` and `[size=…]` BBCode. Until you decide, a color or size raises `Markbridge::UndecidedFeatureError`. phpBB 3.x stores `[size]` as a percentage, and the plugin reads it the same way, so the size value passes as it is:

```ruby
renderer = Markbridge.discourse_renderer(features: { bbcode: true }, sizes: ->(size) { size })

xml = '<r><SIZE size="85"><s>[size=85]</s>small<e>[/size]</e></SIZE></r>'
Markbridge.text_formatter_xml_to_markdown(xml, renderer:).markdown
# => "[size=85]small[/size]"
```

See [Customizing the renderer](/customization/customizing-renderer/#features--the-plugins-of-the-target-site) for `features:`.

## Using the parser directly

```ruby
parser = Markbridge::Parsers::TextFormatter::Parser.new
ast = parser.parse('<r><B><s>[b]</s>bold<e>[/b]</e></B></r>')

renderer = Markbridge::Renderers::Discourse::Renderer.new
renderer.render(ast)
# => "**bold**"
```

## Behavior notes

- **Invalid XML** falls back to treating the input as plain text instead of raising.
- **Unknown elements** are skipped — their children are still processed.
- **Leaf elements** like `<IMG>` and `<ATTACHMENT>` skip their content. It is only the fallback text (the URL or the filename).
- **Stateless handler API**: like the HTML parser, handlers are callables receiving `(element:, parent:, processor:)`. The `processor:` argument is the parser instance and exposes `process_children(xml_element, ast_node)` for handlers that want to recurse manually. Lambdas are accepted.

## When to use this vs. the BBCode parser

If you're migrating **from** phpBB 3.2+ and already have the stored XML, use this parser — it's both faster and closer to the source of truth than re-parsing the BBCode. For plain BBCode from other forums, use the [BBCode parser](/format-guides/bbcode/).
