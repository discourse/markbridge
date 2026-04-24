---
title: TextFormatter → Markdown
description: Convert s9e/TextFormatter XML (used by phpBB 3.2+) into Discourse-flavored Markdown.
---

The TextFormatter parser reads the XML format produced by <a href="https://github.com/s9e/TextFormatter" class="nowrap">s9e/TextFormatter</a>, the library phpBB 3.2+ uses to store parsed BBCode. Converting the stored XML directly is faster and more faithful than re-parsing the original BBCode.

## Requirements

`nokogiri` is required for XML parsing.

## Quick start

```ruby
require "markbridge/all"

xml = "<r><B><s>[b]</s>Hello<e>[/b]</e></B> world!</r>"
Markbridge.text_formatter_xml_to_markdown(xml)
# => "**Hello** world!"
```

## The s9e format in brief

TextFormatter wraps content in one of two roots:

- `<t>` — plain text (no BBCode was used).
- `<r>` — rich text (contains formatted elements).

Inside `<r>`, formatted children use **uppercase element names** by convention (`<B>`, `<URL>`, `<CODE>`). Each formatted element may wrap its original BBCode markup in `<s>` (start) and `<e>` (end) tags — Markbridge ignores these during parsing.

## Supported elements

| Element | AST node | Attributes |
|---|---|---|
| `<B>` | `AST::Bold` | |
| `<I>` | `AST::Italic` | |
| `<S>` | `AST::Strikethrough` | |
| `<U>` | `AST::Underline` | |
| `<CODE>` | `AST::Code` | `lang` |
| `<URL>` | `AST::Url` | `url` |
| `<EMAIL>` | `AST::Url` (mailto) | `email` |
| `<IMG>` | `AST::Image` | `src` |
| `<ATTACHMENT>` | `AST::Attachment` | |
| `<QUOTE>` | `AST::Quote` | attribution attributes |
| `<LIST>` | `AST::List` | `type` ("bullet" / "decimal") |
| `<LI>` | `AST::ListItem` | |
| `<TABLE>`, `<TR>`, `<TD>` | table nodes | |
| `<HR>` | `AST::HorizontalRule` | |
| `<br/>` | `AST::LineBreak` | |

For the exact list, see [`HandlerRegistry.default`](https://github.com/discourse/markbridge/blob/main/lib/markbridge/parsers/text_formatter/handler_registry.rb).

## Using the parser directly

```ruby
parser = Markbridge::Parsers::TextFormatter::Parser.new
ast = parser.parse(xml)

renderer = Markbridge::Renderers::Discourse::Renderer.new
renderer.render(ast)
```

## Behavior notes

- **Invalid XML** falls back to treating the input as plain text instead of raising.
- **Unknown elements** are skipped — their children are still processed.
- **Stateless handler API**: like the HTML parser, handlers are callables receiving `(element:, parent:)`. Lambdas are accepted.

## When to use this vs. the BBCode parser

If you're migrating **from** phpBB 3.2+ and already have the stored XML, use this parser — it's both faster and closer to the source of truth than re-parsing the BBCode. For plain BBCode from other forums, use the [BBCode parser](/guides/bbcode/).
