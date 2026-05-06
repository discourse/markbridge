---
title: BBCode → Markdown
description: Convert BBCode forum markup into Discourse-flavored Markdown.
---

BBCode is Markbridge's most feature-rich input format. The default handler registry covers formatting, lists, tables, quotes, spoilers, images, attachments, sizing, color, alignment, and more.

## Quick start

```ruby
require "markbridge/bbcode"

bbcode = "[b]Hello[/b] [url=https://example.com]world[/url]!"
result = Markbridge.bbcode_to_markdown(bbcode)
result.markdown
# => "**Hello** [world](https://example.com)!"
```

`result` is a [`Markbridge::Conversion`](/migrating/overview/) — `.markdown` is the rendered string, and the same object also exposes `.unknown_tags`, `.diagnostics` (auto-closed counts, depth-exceeded counts, unclosed raw-tag list), `.emissions`, and `.errors`.

To get the AST instead of rendered Markdown:

<!-- spec:continue -->
```ruby
parse = Markbridge.parse_bbcode(bbcode)
parse.ast
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

For most callers, `parse_bbcode` is the better entry point — it returns a `Parse` object that already exposes `.unknown_tags` and `.diagnostics` without reaching for the parser instance.

## Closing strategies

BBCode inputs from real forums often have mismatched or out-of-order tags. Markbridge ships with two strategies:

- **Reordering** (default) — reconciles sequences of up to 5 mismatched closing tags, e.g. `[b][i]text[/b][/i]` → `Bold(Italic("text"))`.
- **Strict** — only auto-closes; won't reorder. More predictable, more likely to reject input.

```ruby
require "markbridge/bbcode"

handlers =
  Markbridge::Parsers::BBCode::HandlerRegistry.build_from_default do |registry|
    reconciler = Markbridge::Parsers::BBCode::ClosingStrategies::TagReconciler.new(registry:)
    registry.closing_strategy = Markbridge::Parsers::BBCode::ClosingStrategies::Strict.new(reconciler)
  end

Markbridge.bbcode_to_markdown("[b][i]text[/b][/i]", handlers:)
```

## Graceful degradation

Unknown tags don't raise. The wrapper is skipped; children are parsed normally:

```ruby
Markbridge.bbcode_to_markdown("[unknown]inner text[/unknown]")
# => "inner text"
```

Unknown tag counts are surfaced on `Conversion#unknown_tags` (and `Parse#unknown_tags`) — no need to drop to the parser instance.

## Limits

- **Max nesting depth**: 100. Exceeding raises `MaxDepthExceededError`.
- **Max auto-close depth**: 5 levels — also bounds how deep `Reordering` will look for a matching opener.

## Customizing

Register a custom handler to recognize a new tag, or replace the built-in one:

<!-- spec:before
class MyCalloutHandler < Markbridge::Parsers::BBCode::Handlers::BaseHandler
  def initialize = (super; @element_class = Markbridge::AST::Element)
  attr_reader :element_class
  def on_open(token:, context:, registry:, tokens: nil)
    context.push(@element_class.new)
  end
end
input = "[callout]hi[/callout]"
-->
```ruby
handlers =
  Markbridge::Parsers::BBCode::HandlerRegistry.build_from_default do |registry|
    registry.register("callout", MyCalloutHandler.new)
  end

Markbridge.bbcode_to_markdown(input, handlers:)
```

See [Extending Markbridge](/customization/extending/) for a full walkthrough, or [Wrapping a default handler](/customization/extending/#wrapping-a-default-handler) for `HandlerRegistry#overlay` — the cleanest way to delegate to the default for the cases your handler doesn't need to change.
