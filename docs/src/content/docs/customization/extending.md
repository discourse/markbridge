---
title: Extending Markbridge
description: Add support for new tags, customize rendering, and swap behavior without patching core.
---

Markbridge has two places to plug in: **handlers** teach a parser to recognize new tags, and **renderer tags** turn AST nodes into Markdown. Both live in registries, so you add your own on top of the defaults without forking the gem.

## Connect parsing and rendering

```
custom BBCode tag  →  custom handler  →  custom AST node  →  custom renderer tag  →  Markdown
```

To support a new tag, register a handler that creates an AST node. Then choose how that node should render. You can register a renderer tag or inherit one from a built-in AST class.

## Adding a custom BBCode tag

### 1. Define the AST node

```ruby
module Markbridge
  module AST
    class Callout < Element
      attr_reader :variant

      def initialize(variant: "info")
        super()
        @variant = variant
      end
    end
  end
end
```

### 2. Write the handler

<!-- spec:continue -->
```ruby
module Markbridge
  module Parsers
    module BBCode
      module Handlers
        class CalloutHandler < BaseHandler
          def initialize
            @element_class = AST::Callout
          end

          attr_reader :element_class

          def on_open(token:, context:, registry:, tokens: nil)
            variant = token.attrs[:option] || "info"
            context.push(AST::Callout.new(variant:))
          end
        end
      end
    end
  end
end
```

### 3. Register the handler

<!-- spec:continue -->
```ruby
handlers =
  Markbridge::Parsers::BBCode::HandlerRegistry.build_from_default do |registry|
    registry.register("callout", Markbridge::Parsers::BBCode::Handlers::CalloutHandler.new)
  end
```

### 4. Write the renderer tag

The block form is the quickest path:

```ruby
callout_tag =
  Markbridge::Renderers::Discourse::Tag.new do |element, interface|
    context = interface.with_parent(element)
    inner = interface.render_children(element, context:)
    if interface.html_mode?
      "<aside>#{inner}</aside>"
    else
      "> [!#{element.variant.upcase}]\n> #{inner.gsub("\n", "\n> ")}\n"
    end
  end
```

### 5. Build a renderer with the tag

<!-- spec:continue -->
```ruby
renderer = Markbridge.discourse_renderer(
  tags: { Markbridge::AST::Callout => callout_tag },
)
```

`tags:` merges on top of the default library, so every other AST class keeps its built-in rendering. See [Customizing the renderer](/customization/customizing-renderer/) for the full set of factory options.

### 6. Use it

<!-- spec:continue -->
```ruby
result = Markbridge.bbcode_to_markdown(
  "[callout=warning]Check this setting.[/callout]",
  handlers:,
  renderer:,
)
result.markdown
# => "> [!WARNING]\n> Check this setting."
```

## The rendering interface

Custom tags receive `(element, interface)`. The interface exposes context-aware helpers:

| Method | Purpose |
|---|---|
| `render_children(element)` | Render child nodes and write their output as Markdown |
| `render_tokens(element)` | The output of the children as inline tokens (`Markbridge::Renderers::Discourse::Inline::Tokens`), for a tag that returns tokens and leaves the markers to the serializer, as the built-in emphasis tags do |
| `render_default(node)` | Render `node` with its stock Tag, bypassing your override — intercept only some nodes and defer the rest |
| `with_parent(element)` | Return a new context that treats `element` as a parent |
| `find_parent(klass)` | Walk up the ancestor chain for a specific AST class |
| `has_parent?(klass)` | Boolean parent check |
| `count_parents(klass)` | Depth of a specific ancestor type (useful for nested lists) |
| `previous_sibling(element)`, `next_sibling(element)`, `sibling(element, offset:)` | The neighbors of an element among the children of its parent (nil at the edges) |
| `previous_list(element)` | The last list in front of the element with nothing visible between them (nil when there is none) |
| `block_context?(element)` | True if the current position is a block context |
| `html_mode?` | True inside a CommonMark HTML block — a Tag that returns a String must emit raw HTML or wrap output as a Markdown island; the serializer takes care of it for tokens |

Use `find_parent` / `has_parent?` to render differently inside specific ancestors (e.g. a code span inside a table cell).

## Tags that return inline tokens

A tag that writes a block, a BBCode wrapper or a block placeholder returns a String, as above. Inline formatting is different: whether `**`, `*` or `[text](url)` means what it should depends on the characters next to it (the flanking rules of emphasis, where a bare URL ends, a `!` in front of a `[`). The built-in emphasis, link and image tags therefore return tokens, and so do the tags that write an inline HTML tag (superscript, subscript), and the renderer's serializer writes them with the neighbors in view. A custom tag can do the same:

```ruby
require "markbridge"

Tokens = Markbridge::Renderers::Discourse::Inline::Tokens

class HighlightTag < Markbridge::Renderers::Discourse::Tag
  def render(element, interface)
    tokens = interface.render_tokens(element, context: interface.with_parent(element))
    tokens.unshift(Tokens.open(:strong)) << Tokens.close(:strong)
  end
end
```

`render_tokens` returns the children's output as an Array of tokens, where finished Markdown from a child is a plain String. The token kinds, all built by `Tokens`:

| Token | Written as |
|---|---|
| a `String` | finished Markdown, as it is |
| `Tokens.text(string)` | the string, escaped like text (`Tokens::LABEL` for a link label, `Tokens::VERBATIM` for none) |
| `Tokens.open(name)` … `Tokens.close(name)` | `**`, `*`, `~~` or `[u]…[/u]` around the content (`:strong`, `:em`, `:s`, `:u`), with whitespace at the edges outside the markers and an HTML fallback where the markers would not work. Every paragraph of the content gets its own markers |
| `Tokens.link_open(destination)` … `Tokens.link_close` | `[content](destination)` |
| `Tokens.bare_url(href)` | the href alone where linkify links it, `[href](href)` where text is glued to it |
| `Tokens.image(src:, alt:, width:, height:)` | `![alt\|WxH](src)` |
| `Tokens.code(content)` | a code span with a backtick run longer than any run in the content |
| `Tokens.hard_break` | a newline; `<br>` on a line that holds nothing else, after a blank line nothing, right after an `html` token `<br>` |
| `Tokens.html(string)` | raw HTML, as it is; a newline right after it becomes `<br>`, so an opening tag is never alone on its line, where it would open an HTML block |
| `Tokens.placeholder(text, like:)` | `text`, as it is, joined with its neighbors as if `like` stood there; for a placeholder that a later step replaces, see [Placeholders](/migrating/placeholders/#tell-markbridge-what-replaces-the-placeholder) |

Inside a CommonMark HTML block (`interface.html_mode?`) the serializer writes the HTML form of every token (`<strong>`, `<a href>`, `<img>`, `<br>`, …), so a tag that returns tokens needs no html_mode branch of its own. A tag that returns a String still does (see below).

Inline markup can't span a blank line: the blank line ends the paragraph, and the markers stay visible as text. A tag that writes its own markers into a String can close them before every blank line and open them again after it with `Markbridge::Renderers::Discourse::Paragraphs.wrap(content, "[x]", "[/x]")`, which keeps whitespace at the edges of every paragraph outside the markers. `Paragraphs.map(content) { |paragraph| … }` yields the paragraphs for anything else. Content with a code fence is one paragraph.

A Tag must return a String — returning `nil` (or anything else) raises a `TypeError`. To handle only some nodes, defer the rest with `render_default(node)` instead of falling through to `nil`.

## Rendering inside HTML blocks

Tables with uneven rows, multiline cells, or nested tables use HTML output. Inside these tables, `interface.html_mode?` is `true`. Each custom tag must return either:

- An HTML equivalent, with user-controlled text and attributes escaped using `Markbridge::Renderers::Discourse::HtmlEscaper`.
- Its Markdown wrapped with `Markbridge::Renderers::Discourse::HtmlBlock.island(markdown)`. This adds blank lines so CommonMark can parse the Markdown. It also adds paragraph spacing, so prefer HTML when a suitable element exists.

The callout example above uses `<aside>` in HTML mode. Child tags receive the same HTML mode through the context.

Test your tag with the shared RSpec example. Use content with Markdown characters so the check can detect unescaped output:

<!-- spec:before
require "rspec"
require "markbridge/all"
CalloutTag = Markbridge::Renderers::Discourse::Tags::BoldTag
Callout = Markbridge::AST::Bold
-->
```ruby
require "markbridge/rspec"

RSpec.describe CalloutTag do
  it_behaves_like "an html_mode safe tag" do
    let(:tag) { described_class.new }
    let(:element) do
      node = Callout.new
      node << Markbridge::AST::Text.new("body *with* Markdown characters")
      node
    end
  end
end
```

Use your own tag and AST classes in place of `CalloutTag` and `Callout`. Override `markbridge_renderer` inside the example if your children need a custom tag library. This structural check complements tests for your expected output.

## AST subclasses

A subclass inherits its base class's normalizer rules and renderer tag. You can add data or identify a group of nodes without repeating the built-in behavior:

```ruby
class LegacyCode < Markbridge::AST::Code
end
```

A `LegacyCode` node uses `CodeTag`. Normalizer rules for `AST::Code` also apply to it. An exact registration for the subclass takes priority over an inherited registration. `interface.render_default(node)` uses the stock tag of the nearest matching class, even when your renderer overrides that class.

To keep only the children instead of using the inherited tag:

<!-- spec:before
class LegacyCode < Markbridge::AST::Code; end
-->
```ruby
renderer = Markbridge.discourse_renderer(
  tags: { LegacyCode => Markbridge::Renderers::Discourse::Tag::PASSTHROUGH }
)
```

Removing the subclass registration with `unregister:` allows the ancestor tag to apply again. See [AST normalization](/concepts/normalization/) to add rules for your own classes.

## HTML and TextFormatter parsers

Both use a simpler, stateless handler API. A handler is an object responding to `#process(element:, parent:)`. Add your node to `parent` and return the node you want children to recurse into, or `nil` to skip them.

<!-- spec:before
input = "<details>hi</details>"
-->
```ruby
class SpoilerHandler < Markbridge::Parsers::HTML::Handlers::BaseHandler
  def initialize
    @element_class = Markbridge::AST::Spoiler
  end

  attr_reader :element_class

  def process(element:, parent:)
    spoiler = Markbridge::AST::Spoiler.new
    parent << spoiler
    spoiler
  end
end

html_handlers =
  Markbridge::Parsers::HTML::HandlerRegistry.build_from_default do |registry|
    registry.register("details", SpoilerHandler.new)
  end

Markbridge.html_to_markdown(input, handlers: html_handlers)
```

The TextFormatter registry works the same way (handlers respond to `#process(element:, parent:, processor:)`), but element names are **UPPERCASE** per s9e convention.

## Replacing a built-in renderer tag

You don't need a new AST node — re-render an existing one however you like by passing it through `tags:`:

```ruby
renderer = Markbridge.discourse_renderer(
  tags: {
    Markbridge::AST::Url =>
      Markbridge::Renderers::Discourse::Tag.new do |element, interface|
        next interface.render_default(element) unless element.href&.start_with?("/")

        link = Markbridge::AST::Url.new(href: "https://forum.example.com#{element.href}")
        element.children.each { |child| link << child }
        interface.render_default(link)
      end,
  }
)
```

## Wrapping a default handler

`HandlerRegistry#overlay` replaces a tag's binding by yielding the previous handler — useful when you want to delegate to the default for the easy cases and only customize the awkward ones:

<!-- spec:before
class LoggingQuoteHandler
  def initialize(default:); @default = default; end
  def auto_closeable?; @default.auto_closeable?; end
  def element_class; @default.element_class; end
  def on_open(token:, context:, registry:, tokens: nil)
    @default.on_open(token:, context:, registry:, tokens:)
  end
  def on_close(token:, context:, registry:, tokens: nil)
    @default.on_close(token:, context:, registry:, tokens:)
  end
end
-->
```ruby
handlers = Markbridge::Parsers::BBCode::HandlerRegistry.default
handlers.overlay("quote") do |default|
  LoggingQuoteHandler.new(default:)
end
```

`overlay` is available on the BBCode, HTML, and TextFormatter `HandlerRegistry`. The yielded `default` is `nil` if nothing was previously registered. (MediaWiki's `InlineTagRegistry` has a different shape — see [Format guides → MediaWiki](/format-guides/mediawiki/).)

When several tag names share one AST class (e.g. `url`/`link`/`iurl` all build `AST::Url`), the wrapper has to be a *single* instance so the closing strategy's element-to-handler lookup matches on both sides. Use plain `register` for that, not `overlay`:

<!-- spec:before
class LoggingUrlHandler
  def initialize(default:); @default = default; end
  def auto_closeable?; @default.auto_closeable?; end
  def element_class; @default.element_class; end
  def on_open(token:, context:, registry:, tokens: nil)
    @default.on_open(token:, context:, registry:, tokens:)
  end
  def on_close(token:, context:, registry:, tokens: nil)
    @default.on_close(token:, context:, registry:, tokens:)
  end
end
handlers = Markbridge::Parsers::BBCode::HandlerRegistry.default
-->
```ruby
default_url = handlers["url"]
handlers.register(%w[url link iurl], LoggingUrlHandler.new(default: default_url))
```

## Convention-based auto-registration

`TagLibrary.new.auto_register!` discovers Markbridge's built-in tags by naming convention:

```ruby
library = Markbridge::Renderers::Discourse::TagLibrary.new
library.auto_register!
# Discovers BoldTag → AST::Bold, ItalicTag → AST::Italic, etc.
```

`auto_register!` only walks `Markbridge::Renderers::Discourse::Tags::*`, so consumer-defined tag classes aren't picked up automatically — register those explicitly via `Markbridge.discourse_renderer(tags: { MyAst => MyTag.new })` or by calling `library.register(MyAst, MyTag.new)` before passing it as `tag_library:` to the factory.

## Migration use cases

When you extend Markbridge for a Discourse migration — links to resolve later, uploads to track, mentions to look up — the same three parts apply. The renderer Tag stays a simple formatter that returns the placeholder string, and you read the placeholder nodes from `conversion.ast.descendants(...)` after conversion. The [Placeholders](/migrating/placeholders/) page is the full guide; this page only covers the general mechanics.

## When to customize vs. fork

- **Unknown tag** in input → register a handler.
- **Known tag, different output** → pass `tags: { ASTClass => MyTag.new }` to `discourse_renderer`.
- **Wrap default behavior** → `HandlerRegistry#overlay` for parser-side; `tags:` overrides for renderer-side.
- **New output format** (not Discourse Markdown) → write a new renderer that walks the AST. The parsers and AST are renderer-agnostic.
