---
title: HTML
description: Convert HTML into Discourse-flavored Markdown using Nokogiri.
---

Use the HTML parser when your source stores posts or pages as HTML: a forum with a WYSIWYG editor, a blog, a help center, a mailing list archive. Nokogiri parses the HTML, so tags that are not closed or nested wrongly are repaired the way a browser repairs them.

## Requirements

Add `nokogiri` to your Gemfile. Markbridge does not depend on it, because the BBCode and MediaWiki parsers work without it:

```ruby
gem "nokogiri"
```

## Quick start

```ruby
require "markbridge/html"

result = Markbridge.html_to_markdown("<p>Hello <strong>world</strong>!</p>")
result.markdown
# => "Hello **world**!"
```

`result` is a [`Markbridge::Conversion`](/concepts/result-objects/). Next to `markdown` it has `unknown_tags`, `diagnostics` and `errors`.

To get the AST:

```ruby
parse = Markbridge.parse_html("<a href='https://example.com'>link</a>")
parse.ast
# => AST::Document(Url("link", href: "https://example.com"))
```

## Supported tags

<div class="format-tags">

| HTML | Renders as | AST node |
|---|---|---|
| `<b>`, `<strong>` | `**bold**` | `AST::Bold` |
| `<i>`, `<em>` | `*italic*` | `AST::Italic` |
| `<s>`, `<strike>` | `~~strike~~` | `AST::Strikethrough` |
| `<u>` | `<u>underline</u>` | `AST::Underline` |
| `<sup>`, `<sub>` | `<sup>…</sup>` / `<sub>…</sub>` | `AST::Superscript`, `AST::Subscript` |
| `<ins>`, `<del>` | `<ins>…</ins>` / `<del>…</del>` | `AST::Insertion`, `AST::Deletion` |
| `<mark>` | `<mark>…</mark>` | `AST::Highlight` |
| `<code>`, `<tt>` | Code span; fenced block for multiline content | `AST::Code` |
| `<pre>` | Fenced code block, including single-line content | `AST::Code` |
| `<h1>`–`<h6>` | `#` through `######` headings | `AST::Heading` |
| `<a href="...">` | `[text](href)` | `AST::Url` |
| `<img src alt>` | `![](src)` | `AST::Image` |
| `<blockquote>` | `[quote="name"]…[/quote]`; without attribution `> …`, or `[quote]…[/quote]` around a quote with attribution | `AST::Quote` |
| `<ul>`, `<ol>` | `- item` / `1. item` | `AST::List` |
| `<li>` | List item | `AST::ListItem` |
| `<table>`, `<tr>`, `<td>`, `<th>` | GFM table, or an HTML table when Markdown cannot express it (a `colspan` or `rowspan`, uneven rows, a block in a cell) | `AST::Table` |
| `<br>` | Hard line break | `AST::LineBreak` |
| `<hr>` | `---` | `AST::HorizontalRule` |
| `<p>` | A paragraph, with a blank line around it | `AST::Paragraph` |
| `<span style="…">` | Bold, italic, underline or strikethrough when the style says so (`font-weight`, `font-style`, `text-decoration`); otherwise its content | the nodes above |

</div>

Relative links and images are written as they are, and Discourse drops an address without a scheme and without a leading slash. Give the renderer the address of the source site as [`base_url:`](/customization/customizing-renderer/#base_url--where-relative-addresses-point-to) to keep them working.

[`HandlerRegistry.default`](https://github.com/discourse/markbridge/blob/main/lib/markbridge/parsers/html/handler_registry.rb) is the exact list.

## Tags without a handler

What the parser does with a tag it has no handler for depends on the tag:

- **Ignored with their content:** `<script>`, `<style>`, `<head>`, `<title>`, `<noscript>`, `<template>`. Nothing of them reaches the output.
- **Transparent:** `<thead>`, `<tbody>`, `<tfoot>`. Their children are processed as if the tag were not there.
- **Unknown:** every other tag, like `<div>`, `<font>` or `<iframe>`. Its children are processed too, and `unknown_tags` counts the tag.

A block-level tag among them, like `<div>` or `<section>`, still keeps its content on a line of its own: `<div>a</div><div>b</div>` is `a`, a line break and `b`. Which tags are block-level is the `block_level_tags` set of the registry.

So the only difference between transparent and unknown is the count. When your source is full of a wrapper you expect, add it to the transparent tags. Then `unknown_tags` only shows what you did not expect:

```ruby
parser =
  Markbridge::Parsers::HTML::Parser.new do |registry|
    registry.transparent_tags.merge(%w[div section font])
  end

parser.parse("<div><b>bold</b></div><custom-card>text</custom-card>")
parser.unknown_tags
# => {"custom-card" => 1}
```

To give such a tag a meaning, for example `<details>` as a spoiler, register a handler. See [Customizing](#customizing) below.

## Code languages

A code block keeps its language for syntax highlighting. The parser takes the first valid one of these:

1. A `language-*` class on the element.
2. A `language-*` class on its direct `<code>` child.
3. The element's `lang` attribute.
4. A single class on the element or its direct `<code>` child.

A valid language starts with a letter or a digit and has only letters, digits, `_`, `+` and `-`. With more than one class and none of them a `language-*` class, like `hljs codeblock`, the block has no language.

```ruby
require "markbridge/html"

result = Markbridge.html_to_markdown('<pre><code class="language-ruby">puts 1</code></pre>')
result.markdown
# => "```ruby\nputs 1\n```"
```

## Whitespace

HTML source is often indented and wrapped, and a browser does not show that. The parser collapses whitespace the same way:

- Several whitespace characters in a row become one space.
- A space at the start or the end of a block is dropped, and so is a space right after another one, also across tags: `<b>a </b> b` keeps one space.
- Text inside `<pre>`, `<code>`, `<textarea>` and `<tt>` stays as it is.

Which tags are blocks and which keep their whitespace is set on the `HandlerRegistry`: `block_level_tags` and `whitespace_preserving_tags`.

## Customizing

A handler is an object with `#process(element:, parent:)`. It adds a node to `parent` and returns the node that the children of the element go into, or `nil` to skip the children:

```ruby
class AsideHandler < Markbridge::Parsers::HTML::Handlers::BaseHandler
  def initialize
    @element_class = AST::Quote
  end

  attr_reader :element_class

  def process(element:, parent:)
    note = AST::Quote.new
    parent << note
    note # the children of <aside> go into the quote
  end
end

handlers =
  Markbridge::Parsers::HTML::HandlerRegistry.build_from_default do |registry|
    registry.register("aside", AsideHandler.new)
  end

Markbridge.html_to_markdown("<aside>heads up</aside>", handlers:)
```

[Extending Markbridge](/customization/extending/#html-and-textformatter-parsers) has more on handlers.

## Using the parser directly

The parser takes a String or a Nokogiri node, so HTML you already parsed is not parsed again:

```ruby
parser = Markbridge::Parsers::HTML::Parser.new
ast = parser.parse("<p>rich <em>content</em></p>")

renderer = Markbridge::Renderers::Discourse::Renderer.new
renderer.render(ast)
```

## Limits

The default handlers cover the HTML that has a form in Discourse Markdown. What they leave out:

- **Styles.** Colors, sizes and fonts in a `style` attribute or a `<font>` tag are dropped. Only the bold, italic, underline and strikethrough of a `<span>` are read.
- **Embeds.** `<iframe>`, `<video>`, `<audio>` and `<object>` have no handler. Only the fallback content between their tags is written, not the address of the embed. Register a handler that writes a link if you need them.
- **`<details>`, `<dl>`, `<figure>`** and other structures have no handler either. Their text is kept, their structure is not.
