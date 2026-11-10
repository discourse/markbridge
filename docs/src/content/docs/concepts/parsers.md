---
title: Parsers
description: How the four parsers work and where they differ.
---

Each parser reads one input format. All four build the same AST and follow the same rules for bad input. How they work inside differs, and so does the way you extend them.

## What all parsers share

- **Bad input does not raise.** Forum content is full of broken markup, and a migration must not stop at one post.
- **A tag without a handler is counted, not kept.** Its content is parsed as if the tag were not there. `unknown_tags` on the result has the count per tag name.
- **The root is an `AST::Document`.**
- **Line endings are normalized**, CRLF to LF, before parsing.

## BBCode

`Markbridge::Parsers::BBCode::Parser` is written by hand and works in two stages.

The **scanner** turns the input into tokens: text, an opening tag, a closing tag. It works on byte offsets, because an index by character is slow on text with multibyte characters.

The **parser** gives every tag token to the handler registered for the tag name. A handler has two callbacks, `on_open` and `on_close`, and pushes or pops elements on the stack of open elements (`ParserState`). The stack is limited to 100 levels.

BBCode from real forums often closes tags in the wrong order, like `[b][i]text[/b][/i]`. A closing strategy decides what to do:

- `Reordering` (the default) looks ahead up to five closing tags and matches them with the open elements.
- `Strict` only closes the open elements on top of the stack.

See the [BBCode guide](/format-guides/bbcode/#closing-strategies) for how to choose one.

## HTML

`Markbridge::Parsers::HTML::Parser` lets Nokogiri parse the HTML and walks the result. Nokogiri repairs broken HTML, so Markbridge does not have to.

A handler here is simpler than a BBCode handler. It is an object with `#process(element:, parent:)`. It adds a node to `parent` and returns the node the children of the element go into, or `nil` to skip the children:

<!-- spec:before
require "markbridge/html"
registry = Markbridge::Parsers::HTML::HandlerRegistry.default
-->
```ruby
class AsideHandler < Markbridge::Parsers::HTML::Handlers::BaseHandler
  # No AST node for <aside>: its children go into the parent.
  def process(element:, parent:)
    parent
  end
end

registry.register("aside", AsideHandler.new)
```

The parser collapses whitespace like a browser does, except inside `<pre>` and `<code>`.

## TextFormatter

`Markbridge::Parsers::TextFormatter::Parser` reads the XML that <a href="https://github.com/s9e/TextFormatter" class="nowrap">s9e\TextFormatter</a> stores. phpBB 3.2+ and Flarum save posts in this form, not as the BBCode or Markdown the user typed.

Handlers work like in the HTML parser. What is special is the format:

- The root is `<t>` for plain text or `<r>` for text with markup.
- Elements have uppercase names: `<B>`, `<URL>`, `<QUOTE>`.
- The markup the user typed is kept in `<s>`, `<e>` and `<i>` elements. The parser skips them.

Input that is not valid XML is read as plain text.

## MediaWiki

`Markbridge::Parsers::MediaWiki::Parser` has no handler registry for blocks. The block syntax of wikitext is fixed, so the parser reads the input line by line and decides what each line is: a heading, a list item, a table row, indented code, or text. An `InlineParser` reads the markup inside a line (`'''bold'''`, `[[links]]`).

The one thing you can register is HTML-like inline tags (`<nowiki>`, `<sup>`, `<mark>`), in the `InlineTagRegistry`. For anything else, change the AST after parsing. See the [MediaWiki guide](/format-guides/mediawiki/#using-the-parser-directly).

## Which parser for which input

| Input looks like | Parser |
|---|---|
| `[b]…[/b]` | BBCode |
| `<p><strong>…</strong></p>` | HTML |
| `<r><B>…</B></r>` | TextFormatter |
| `'''bold''' and [[links]]` | MediaWiki |

phpBB 3.2+ stores the XML of s9e\TextFormatter, and the XML has the BBCode in it. Use the TextFormatter parser there, not the BBCode parser: the XML says what phpBB made of every tag, so nothing has to be guessed again.
