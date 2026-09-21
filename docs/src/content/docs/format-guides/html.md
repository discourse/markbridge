---
title: HTML
description: Convert HTML into Discourse-flavored Markdown using Nokogiri.
---

The HTML parser uses Nokogiri to tolerate malformed HTML and produces the same AST the other parsers feed into.

## Requirements

Add `nokogiri` to your Gemfile. It's a runtime dependency for the HTML parser:

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

`result` is a [`Markbridge::Conversion`](/concepts/result-objects/) — `.markdown`, plus `.unknown_tags`, `.errors` for migration use.

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
| `<s>`, `<strike>`, `<del>` | `~~strike~~` | `AST::Strikethrough` |
| `<u>` | `<u>underline</u>` | `AST::Underline` |
| `<sup>`, `<sub>` | `<sup>…</sup>` / `<sub>…</sub>` | `AST::Superscript`, `AST::Subscript` |
| `<code>`, `<tt>` | Code span; fenced block for multiline content | `AST::Code` |
| `<pre>` | Fenced code block, including single-line content | `AST::Code` |
| `<h1>`–`<h6>` | `#` through `######` headings | `AST::Heading` |
| `<a href="...">` | `[text](href)` | `AST::Url` |
| `<img src alt>` | `![](src)` | `AST::Image` |
| `<blockquote>` | `[quote]…[/quote]` | `AST::Quote` |
| `<ul>`, `<ol>` | `- item` / `1. item` | `AST::List` |
| `<li>` | List item | `AST::ListItem` |
| `<table>`, `<tr>`, `<td>`, `<th>` | GFM table | `AST::Table` |
| `<br>` | Hard line break | `AST::LineBreak` |
| `<hr>` | `---` | `AST::HorizontalRule` |
| `<p>` | Paragraph spacing | — (transparent) |

</div>

`<thead>`, `<tbody>`, `<tfoot>` are transparent — their children are processed as if the wrapper weren't there. Unregistered tags are skipped, but their children are still processed (graceful degradation).

For the authoritative list, see [`HandlerRegistry.default`](https://github.com/discourse/markbridge/blob/main/lib/markbridge/parsers/html/handler_registry.rb).

## Code languages

For syntax highlighting, the parser uses the first valid language from:

1. A `language-*` class on the element.
2. A `language-*` class on its direct `<code>` child.
3. The element's `lang` attribute.
4. A single class on the element or its direct `<code>` child.

The language must contain only letters, digits, underscores, plus signs, or hyphens, and start with a letter or digit. A class list such as `hljs codeblock` does not become a language.

```ruby
require "markbridge/html"

result = Markbridge.html_to_markdown('<pre><code class="language-ruby">puts 1</code></pre>')
result.markdown
# => "```ruby\nputs 1\n```"
```

## Parser characteristics

- **Uses Nokogiri's HTML fragment parser** — handles malformed input without raising.
- **Stateless handlers** — simpler than BBCode's open/close callback API. A handler is an object responding to `#process(element:, parent:)`.
- **Collapses whitespace like a browser** — runs of whitespace become one space, and a space at the start or end of a line (a block boundary) or right after another space is dropped, wherever the inline boundaries fall: `<b>a </b> b` keeps one space. Text inside `<pre>`, `<code>`, `<textarea>` and `<tt>` is kept verbatim. Both tag sets are configurable on the `HandlerRegistry` (`block_level_tags`, `whitespace_preserving_tags`).

```ruby
class AsideHandler < Markbridge::Parsers::HTML::Handlers::BaseHandler
  def initialize
    @element_class = AST::Quote
  end

  attr_reader :element_class

  def process(element:, parent:)
    note = AST::Quote.new
    parent << note
    note # return node to recurse into for children
  end
end

handlers =
  Markbridge::Parsers::HTML::HandlerRegistry.build_from_default do |registry|
    registry.register("aside", AsideHandler.new)
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
- If you need semantic mappings for something richer (for example `<details>` → spoiler), register a handler — see [Extending Markbridge](/customization/extending/).
