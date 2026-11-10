---
title: BBCode
description: Convert BBCode forum markup into Discourse-flavored Markdown.
---

BBCode is what most forum software stores: phpBB before 3.2, vBulletin, XenForo, SMF, MyBB and many others. Every forum has its own dialect, so the parser knows the common tags and their aliases, repairs tags that are closed in the wrong order, and lets you register handlers for the tags only your forum has.

## Quick start

```ruby
require "markbridge/bbcode"

bbcode = "[b]Hello[/b] [url=https://example.com]world[/url]!"
result = Markbridge.bbcode_to_markdown(bbcode)
result.markdown
# => "**Hello** [world](https://example.com)!"
```

`result` is a [`Markbridge::Conversion`](/concepts/result-objects/). Next to `markdown` it has `unknown_tags`, `diagnostics` (what the parser had to repair) and `errors`.

To get the AST without rendering it:

<!-- spec:continue -->
```ruby
parse = Markbridge.parse_bbcode(bbcode)
parse.ast
# => an AST::Document with Bold("Hello"), Text(" "), Url("world") and Text("!")
```

## Supported tags

Tag names are read in any case, `[B]` like `[b]`. The tags in one row are aliases: they have the same handler.

<div class="format-tags">

### Formatting

| Tags | Renders as | AST node |
|---|---|---|
| `[b]`, `[bold]`, `[strong]` | `**bold**` | `AST::Bold` |
| `[i]`, `[italic]`, `[em]` | `*italic*` | `AST::Italic` |
| `[s]`, `[strike]`, `[del]` | `~~strike~~` | `AST::Strikethrough` |
| `[u]`, `[underline]` | `<u>underline</u>` | `AST::Underline` |
| `[sup]` | `<sup>sup</sup>` | `AST::Superscript` |
| `[sub]` | `<sub>sub</sub>` | `AST::Subscript` |

### Code

| Tags | Renders as | AST node |
|---|---|---|
| `[code]`, `[pre]` | Fenced code block, including single-line content | `AST::Code` |
| `[tt]` | Code span; fenced block for multiline content | `AST::Code` |

### Links, images, attachments

| Tags | Renders as | AST node |
|---|---|---|
| `[url]`, `[link]`, `[iurl]` | `[text](href)` | `AST::Url` |
| `[email]` | `[text](mailto:addr)` | `AST::Email` |
| `[img]` | `![](src)` | `AST::Image` |
| `[attach]`, `[attachment]` | Discourse upload syntax | `AST::Attachment` |

### Blocks

| Tags | Renders as | AST node |
|---|---|---|
| `[quote]` | `[quote="name"]…[/quote]`; without attribution `> …`, or `[quote]…[/quote]` around a quote with attribution | `AST::Quote` |
| `[spoiler]`, `[hide]` | `[spoiler]…[/spoiler]`, a title as text in front | `AST::Spoiler` |
| `[color]` | `[color=…]…[/color]` with `features: { bbcode: true }`, the text with `bbcode: false`; raises until decided | `AST::Color` |
| `[size]` | `[size=…]…[/size]` with `features: { bbcode: true }` and `sizes:`, the text with `bbcode: false`; raises until decided | `AST::Size` |
| `[center]`, `[left]`, `[right]`, `[justify]` | `<div align="…">` | `AST::Align` |

### Lists

| Tags | Renders as | AST node |
|---|---|---|
| `[list]`, `[ul]`, `[ulist]` | `- item` | `AST::List` |
| `[ol]`, `[olist]` | `1. item` | `AST::List` |
| `[*]`, `[li]` | List item | `AST::ListItem` |

### Tables

| Tags | Renders as | AST node |
|---|---|---|
| `[table]`, `[tr]`, `[td]`, `[th]` | GFM table, or an HTML table when Markdown cannot express it (a `colspan` or `rowspan`, uneven rows, a block in a cell) | `AST::Table` |

### Self-closing

| Tags | Renders as | AST node |
|---|---|---|
| `[br]` | Hard line break | `AST::LineBreak` |
| `[hr]` | `---` | `AST::HorizontalRule` |

</div>

### Options and other forms

- **Code language:** `[code=ruby]` or `[code lang=ruby]`.
- **Ordered list:** `[list=1]`, the same as `[ol]`.
- **Quote with an author:** `[quote="author, post:1, topic:2"]`.
- **Links:** `[url=href]text[/url]` or `[url]href[/url]`. `[email=addr]text[/email]` and `[img=src]alt[/img]` work the same way.
- **A link without a text of its own** is written as the bare URL, not as `[href](href)`. Discourse links a bare URL itself and shows a onebox for it when it stands on its own line.
- **Relative links and images** are written as they are. Discourse drops an address without a scheme and without a leading slash, so give the renderer the address of the old forum as [`base_url:`](/customization/customizing-renderer/#base_url--where-relative-addresses-point-to).
- **An option without quotes** runs up to the `]`, with its spaces: `[quote=John Doe]` quotes "John Doe". It ends earlier at a named attribute, so `[quote=John Doe post_id=4]` has the option "John Doe" and the attribute `post_id`. A line break ends it too.

[`HandlerRegistry.default`](https://github.com/discourse/markbridge/blob/main/lib/markbridge/parsers/bbcode/handler_registry.rb) is the exact list.

## Using the parser directly

`bbcode_to_markdown` runs the parser and the renderer for you. You can also call them yourself:

```ruby
parser = Markbridge::Parsers::BBCode::Parser.new
ast = parser.parse("[b]bold[/b] with [unknown]mystery[/unknown]")

parser.unknown_tags
# => {"unknown" => 2}   # count of open + close tokens seen

renderer = Markbridge::Renderers::Discourse::Renderer.new
renderer.render(ast)
# => "**bold** with mystery"
```

`Markbridge.parse_bbcode` is easier in most cases. It returns a `Parse` that has the AST, `unknown_tags` and `diagnostics` in one object. Calling the renderer yourself also skips normalizing and the final cleanup of the output, which `Markbridge.render(parse)` does for you.

## Closing strategies

BBCode from real forums often closes tags in the wrong order, or not at all. A closing strategy decides what the parser makes of that. There are two:

- **Reordering** is the default. It looks ahead up to five closing tags and matches them with the open tags, so `[b][i]text[/b][/i]` is bold and italic text.
- **Strict** never reorders. A closing tag closes the open tags inside it, and a closing tag that matches nothing stays as text. Use it when your source is clean and you want to see every tag that is not.

To use the strict one:

```ruby
require "markbridge/bbcode"

handlers =
  Markbridge::Parsers::BBCode::HandlerRegistry.build_from_default do |registry|
    reconciler = Markbridge::Parsers::BBCode::ClosingStrategies::TagReconciler.new(registry:)
    registry.closing_strategy = Markbridge::Parsers::BBCode::ClosingStrategies::Strict.new(reconciler)
  end

Markbridge.bbcode_to_markdown("[b][i]text[/b][/i]", handlers:)
```

## Unknown tags

A tag without a handler does not raise. The tag itself is dropped and its content is parsed like any other content:

```ruby
Markbridge.bbcode_to_markdown("[unknown]inner text[/unknown]")
# => "inner text"
```

`unknown_tags` on the result counts them, opening and closing tags each: `{"unknown" => 2}` here. Collect the counts over all your posts to see which tags need a handler.

## Limits

- **Nesting stops at 100 levels.** A tag that opens deeper than that stays in the output as text, and `diagnostics[:depth_exceeded_count]` counts it.
- **A closing tag closes at most five open tags inside it.** `Reordering` also looks no further than five tags to find a match.

## Customizing

Register a handler for a tag the parser does not know, or to replace a built-in one:

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

[Extending Markbridge](/customization/extending/) shows the handler, the AST node and the renderer tag for a new tag step by step. To change a built-in handler only for some cases, wrap it: see [Wrapping a default handler](/customization/extending/#wrapping-a-default-handler).
