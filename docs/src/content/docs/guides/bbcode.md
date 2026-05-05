---
title: BBCode → Markdown
description: Convert BBCode forum markup into Discourse-flavored Markdown.
---

BBCode is Markbridge's most feature-rich input format. The default handler registry covers formatting, lists, tables, quotes, spoilers, images, attachments, sizing, color, alignment, and more.

## Quick start

```ruby
require "markbridge/all"

bbcode = "[b]Hello[/b] [url=https://example.com]world[/url]!"
Markbridge.bbcode_to_markdown(bbcode)
# => "**Hello** [world](https://example.com)!"
```

To get the AST instead of rendered Markdown:

```ruby
ast = Markbridge.parse_bbcode(bbcode)
# => AST::Document(Bold("Hello"), Text(" "), Url("world", href: "..."))
```

## Supported tags

All tag names are case-insensitive. Aliases in the same row behave identically.

### Formatting

| Tags | Output | AST node |
|---|---|---|
| `[b]`, `[bold]`, `[strong]` | `**bold**` | `AST::Bold` |
| `[i]`, `[italic]`, `[em]` | `*italic*` | `AST::Italic` |
| `[s]`, `[strike]`, `[del]` | `~~strike~~` | `AST::Strikethrough` |
| `[u]`, `[underline]` | `<u>underline</u>` | `AST::Underline` |
| `[sup]` | `<sup>sup</sup>` | `AST::Superscript` |
| `[sub]` | `<sub>sub</sub>` | `AST::Subscript` |

### Code

| Tags | Notes |
|---|---|
| `[code]`, `[pre]`, `[tt]` | Raw content — inner BBCode is not parsed. Supports `[code=ruby]` or `[code lang=ruby]` for language hints. |

### Links, images, attachments

| Tags | Notes |
|---|---|
| `[url]`, `[link]`, `[iurl]` | Accepts `[url=href]text[/url]`, `[url href=...]text[/url]`, or `[url]href[/url]` |
| `[email]` | `[email=addr]text[/email]` renders as a `mailto:` link |
| `[img]` | `[img]src[/img]` or `[img=src]alt[/img]` |
| `[attach]`, `[attachment]` | Renders Discourse attachment syntax |

### Blocks

| Tags | Notes |
|---|---|
| `[quote]` | Supports `[quote="author, post:1, topic:2"]` for Discourse-style attribution |
| `[spoiler]`, `[hide]` | Renders Discourse `[spoiler]` Markdown |
| `[color]` | `[color=red]text[/color]` |
| `[size]` | `[size=5]text[/size]` |
| `[center]`, `[left]`, `[right]`, `[justify]` | Alignment |

### Lists

| Tags | Notes |
|---|---|
| `[list]`, `[ul]`, `[ulist]` | Unordered list. `[list=1]` makes it ordered. |
| `[ol]`, `[olist]` | Ordered list |
| `[*]`, `[li]`, `[.]` | List item. Auto-closes the previous item and any open item at the end of the list. |

### Tables

| Tags | Notes |
|---|---|
| `[table]`, `[tr]`, `[td]`, `[th]` | Rendered as GFM tables |

### Self-closing

| Tags | Notes |
|---|---|
| `[br]` | Hard line break |
| `[hr]` | Horizontal rule |

For the exact registration list, see [`HandlerRegistry.default`](https://github.com/discourse/markbridge/blob/main/lib/markbridge/parsers/bbcode/handler_registry.rb).

## Using the parser directly

The `bbcode_to_markdown` convenience wraps parser + renderer. Calling them directly gives you the AST for inspection or custom rendering:

```ruby
parser = Markbridge::Parsers::BBCode::Parser.new
ast = parser.parse("[b]bold[/b] with [unknown]mystery[/unknown]")

parser.unknown_tags
# => {"unknown" => 2}   # count of open + close tokens seen

renderer = Markbridge::Renderers::Discourse::Renderer.new
renderer.render(ast)
# => "**bold** with mystery"
```

## Closing strategies

BBCode inputs from real forums often have mismatched or out-of-order tags. Markbridge ships with two strategies:

- **Reordering** (default) — reconciles sequences of up to 5 mismatched closing tags, e.g. `[b][i]text[/b][/i]` → `Bold(Italic("text"))`.
- **Strict** — only auto-closes; won't reorder. More predictable, more likely to reject input.

```ruby
require "markbridge/parsers/bbcode"

strategy = Markbridge::Parsers::BBCode::ClosingStrategies::Strict.new

handlers =
  Markbridge::Parsers::BBCode::HandlerRegistry.build_from_default do |registry|
    registry.closing_strategy = strategy
  end

Markbridge.bbcode_to_markdown("[b][i]text[/b][/i]", handlers:)
```

## Graceful degradation

Unknown tags don't raise. The wrapper is skipped; children are parsed normally:

```ruby
Markbridge.bbcode_to_markdown("[unknown]inner text[/unknown]")
# => "inner text"
```

Unknown tag counts are available on the parser instance when you call it directly (see above).

## Limits

- **Max nesting depth**: 100. Exceeding raises `MaxDepthExceededError`.
- **Max auto-close depth**: 5 levels — also bounds how deep `Reordering` will look for a matching opener.

## Customizing

Register a custom handler to recognize a new tag, or replace the built-in one:

```ruby
handlers =
  Markbridge::Parsers::BBCode::HandlerRegistry.build_from_default do |registry|
    registry.register("callout", MyCalloutHandler.new)
  end

Markbridge.bbcode_to_markdown(input, handlers:)
```

See [Extending Markbridge](/guides/extending/) for a full walkthrough.
