---
title: HTML → Markdown
description: Convert HTML into Discourse-flavored Markdown using Nokogiri.
---

The HTML parser uses Nokogiri to tolerate malformed HTML and produces the same AST the other parsers feed into.

## Requirements

Add `nokogiri` to your Gemfile. It's a runtime dependency only for the HTML parser:

```ruby
gem "nokogiri"
```

## Quick start

```ruby
require "markbridge/all"

Markbridge.html_to_markdown("<p>Hello <strong>world</strong>!</p>")
# => "Hello **world**!"
```

To get the AST:

```ruby
ast = Markbridge.parse_html("<a href='https://example.com'>link</a>")
# => AST::Document(Url("link", href: "https://example.com"))
```

## Supported tags

| HTML | AST node |
|---|---|
| `<b>`, `<strong>` | `AST::Bold` |
| `<i>`, `<em>` | `AST::Italic` |
| `<s>`, `<strike>`, `<del>` | `AST::Strikethrough` |
| `<u>` | `AST::Underline` |
| `<sup>`, `<sub>` | `AST::Superscript`, `AST::Subscript` |
| `<code>`, `<pre>`, `<tt>` | `AST::Code` (raw content) |
| `<a href="...">` | `AST::Url` |
| `<img src alt>` | `AST::Image` |
| `<blockquote>` | `AST::Quote` |
| `<ul>`, `<ol>` | `AST::List` |
| `<li>` | `AST::ListItem` |
| `<table>`, `<tr>`, `<td>`, `<th>` | `AST::Table`, `AST::TableRow`, `AST::TableCell` |
| `<br>` | `AST::LineBreak` |
| `<hr>` | `AST::HorizontalRule` |
| `<p>` | Transparent — adds spacing, no AST node |

`<thead>`, `<tbody>`, `<tfoot>` are transparent — their children are processed as if the wrapper weren't there. Unregistered tags are skipped, but their children are still processed (graceful degradation).

For the authoritative list, see [`HandlerRegistry.default`](https://github.com/discourse/markbridge/blob/main/lib/markbridge/parsers/html/handler_registry.rb).

## Parser characteristics

- **Uses Nokogiri's HTML fragment parser** — handles malformed input without raising.
- **Stateless handlers** — simpler than BBCode's open/close callback API. A handler is a callable that takes `(element:, parent:)`.
- **Lambda support** — you can register a plain lambda for quick customization instead of a class.

```ruby
handlers =
  Markbridge::Parsers::HTML::HandlerRegistry.build_from_default do |registry|
    registry.register("aside", ->(element:, parent:) {
      note = AST::Quote.new
      parent << note
      note  # return node to recurse into for children
    })
  end

Markbridge.html_to_markdown("<aside>heads up</aside>", handlers:)
```

## Using the parser directly

```ruby
parser = Markbridge::Parsers::HTML::Parser.new
ast = parser.parse("<p>rich <em>content</em></p>")

renderer = Markbridge::Renderers::Discourse::Renderer.new
renderer.render(ast)
```

## What's not supported

The default registry is intentionally scoped to the Discourse-facing subset. Notably:

- Inline styles and `<span>`/`<div>` without handlers pass through transparently (children only).
- `<script>`, `<style>`, `<iframe>` and similar tags are not registered; children are still processed.
- If you need semantic mappings for something richer (for example `<details>` → spoiler), register a handler — see [Extending Markbridge](/guides/extending/).
