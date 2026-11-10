---
title: TextFormatter
description: Convert the XML that s9e\TextFormatter stores (phpBB 3.2+, Flarum) into Discourse-flavored Markdown.
---

<a href="https://github.com/s9e/TextFormatter" class="nowrap">s9e\TextFormatter</a> is the PHP library that phpBB 3.2+ and Flarum format posts with. These forums do not store what the user typed. They store XML that the library made of it, with the BBCode or Markdown markup still inside. If the post column of your database starts with `<r>` or `<t>`, this is your format.

Read the XML, not the markup inside it. The XML says what the forum made of every tag: which `[b]` was really bold, where a list item ends, what a bare URL links to. A BBCode parser would have to guess all of that again.

## Requirements

Add `nokogiri` to your Gemfile. Markbridge does not depend on it, because the BBCode and MediaWiki parsers work without it:

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

## The format in short

The root element says whether the post has markup:

- `<t>` is plain text.
- `<r>` is text with markup ("rich").

Inside `<r>`, the elements with a meaning have uppercase names: `<B>`, `<URL>`, `<CODE>`. The markup the user typed is kept next to them in three lowercase elements, which the parser skips:

- `<s>` and `<e>` hold the start and the end markup of an element, like `[b]` and `[/b]`.
- `<i>` holds text that s9e ignored, like the newline after `[list]` or a `[/b]` that closes nothing. Do not mix it up with `<I>`, which is italic.

A line break is stored as `<br/>` with a newline after it: `a<br/>\nb`. The forum shows the XML as HTML, where that newline and spaces at the start of a line are not visible. The parser removes them, so `a<br/>\nb` is `a\nb` in Markdown and an indented line does not become a code block. Two `<br/>` are a blank line. Text inside `<CODE>` stays as it is.

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
| `<EMAIL>` | `[text](mailto:addr)` | `AST::Email` |
| `<IMG>` | `![](src)` | `AST::Image` |
| `<ATTACHMENT>`, `<ATTACH>` | Discourse upload syntax | `AST::Attachment` |
| `<QUOTE>` | `[quote="name"]…[/quote]`; without attribution `> …`, or `[quote]…[/quote]` around a quote with attribution | `AST::Quote` |
| `<LIST>` | `- item` / `1. item` | `AST::List` |
| `<LI>` | List item | `AST::ListItem` |
| `<TABLE>`, `<TR>`, `<TD>`, `<TH>` | GFM table, or an HTML table when Markdown cannot express it (a `colspan` or `rowspan`, uneven rows, a block in a cell) | `AST::Table` |
| `<COLOR>`, `<SIZE>` | See [Colors and sizes](#colors-and-sizes) | `AST::Color`, `AST::Size` |
| `<ALIGN>`, `<CENTER>`, `<LEFT>`, `<RIGHT>`, `<JUSTIFY>` | `<div align="…">` | `AST::Align` |
| `<SPOILER>` | Block spoiler: `[spoiler]` and `[/spoiler]` on lines of their own, a title as a paragraph in front | `AST::Spoiler` with `block: true` |
| `<ISPOILER>` | `[spoiler]…[/spoiler]` inside the line | `AST::Spoiler` |
| `<HR>` | `---` | `AST::HorizontalRule` |
| `<br/>` | Hard line break | `AST::LineBreak` |

</div>

### Litedown

Litedown is the Markdown plugin of s9e\TextFormatter. Flarum uses it, so a Flarum post is Markdown that was stored as XML. Litedown has elements of its own next to the BBCode ones:

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

`<QUOTE>`, `<LIST>`, `<LI>`, `<URL>`, `<EMAIL>`, `<IMG>` and `<HR>` are the same elements as for BBCode. The Markdown markers (`**`, `#`, `>`) are in `<s>`, `<e>` and `<i>` elements, like the BBCode tags.

Three more elements have no handler on purpose: `<ESC>` (a character the user escaped with a backslash), `<E>` (an emoticon) and `<EMOJI>`. Their text goes into the output and `unknown_tags` does not count them. They are the `transparent_tags` of the `HandlerRegistry`. Add your own to the set like in the [HTML parser](/format-guides/html/#tags-without-a-handler).

Flarum's own elements have no handler, for example `<USERMENTION>` and `<POSTMENTION>`. Their text is kept and `unknown_tags` counts them. Register handlers for the ones your forum uses, see [Extending Markbridge](/customization/extending/#html-and-textformatter-parsers).

### Notes on the elements

phpBB shows a `[spoiler]` as a block, so `<SPOILER>` is a block spoiler and the text after it starts a new line. `<ISPOILER>` is the inline spoiler of the Litedown plugin. `<HR>` comes from the `[hr]` BBCode of the s9e repository and from Litedown.

The parser reads these attributes: `lang` of `<CODE>`, `url` of `<URL>`, `email` of `<EMAIL>`, `src` of `<IMG>`, `type` of `<LIST>` (`bullet` or `decimal`), the author of `<QUOTE>`, and `colspan` and `rowspan` of `<TD>` and `<TH>`.

Relative links and images are written as they are, and Discourse drops an address without a scheme and without a leading slash. Give the renderer the address of the old forum as [`base_url:`](/customization/customizing-renderer/#base_url--where-relative-addresses-point-to).

[`HandlerRegistry.default`](https://github.com/discourse/markbridge/blob/main/lib/markbridge/parsers/text_formatter/handler_registry.rb) is the exact list.

## Colors and sizes

Discourse shows colors and sizes only with the discourse-bbcode plugin. Markbridge cannot know whether your site has it, so you have to say:

- `features: { bbcode: false }` writes the text without color and size.
- `features: { bbcode: true }` writes `[color=…]` and `[size=…]` BBCode for the plugin.

Without the decision, the first color or size raises `Markbridge::UndecidedFeatureError`.

phpBB 3.x stores `[size]` as a percentage and the plugin reads it as one, so the size passes as it is:

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

## What else to know

- **Input that is not valid XML** is read as plain text. Nothing is raised.
- **An element without a handler** is dropped and its content is processed. `unknown_tags` counts it.
- **The content of `<IMG>` and `<ATTACHMENT>` is skipped.** It is only the URL or the filename again.
- **A handler** is an object with `#process(element:, parent:, processor:)`, or a lambda with the same keywords. `processor` is the parser. Call `processor.process_children(xml_element, ast_node)` when the handler has to process the children itself.
