---
title: Extending Markbridge
description: Add support for new tags, customize rendering, and swap behavior without patching core.
---

Markbridge exposes two extension points: **handlers** teach a parser to recognize new tags; **renderer tags** turn AST nodes into Markdown. Both use registries, so you can layer customizations onto the defaults without forking.

## The two-step mental model

```
custom BBCode tag  →  custom handler  →  custom AST node  →  custom renderer tag  →  Markdown
```

Most of the time you need *both* ends — the parser has to produce a node, and the renderer has to know how to output it.

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
    inner = interface.render_children(element)
    "> [!#{element.variant.upcase}]\n> #{inner.gsub("\n", "\n> ")}\n"
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
  "[callout=warning]Heads up![/callout]",
  handlers:,
  renderer:,
)
result.markdown
# => "> [!WARNING]\n> Heads up!\n"
```

## The rendering interface

Custom tags receive `(element, interface)`. The interface exposes context-aware helpers:

| Method | Purpose |
|---|---|
| `render_children(element)` | Render child nodes and concatenate their output |
| `with_parent(element)` | Return a new context that treats `element` as a parent |
| `find_parent(klass)` | Walk up the ancestor chain for a specific AST class |
| `has_parent?(klass)` | Boolean parent check |
| `count_parents(klass)` | Depth of a specific ancestor type (useful for nested lists) |
| `wrap_inline(content, markers)` | Wrap inline content, collapsing adjacent markers cleanly |
| `block_context?(element)` | True if the current position is a block context |
| `html_mode?` | True inside a CommonMark HTML block — the Tag must emit raw HTML or wrap output as a Markdown island |

Use `find_parent` / `has_parent?` to render differently inside specific ancestors (e.g. a code span inside a table cell).

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
        # Custom link rendering — e.g., prefix internal links
        href = element.href.start_with?("/") ? "https://forum.example.com#{element.href}" : element.href
        "[#{interface.render_children(element)}](#{href})"
      end,
  }
)
```

## Wrapping a default handler

`HandlerRegistry#overlay` replaces a tag's binding by yielding the previous handler — useful when you want to delegate to the default for the easy cases and only customize the awkward ones:

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
-->
```ruby
handlers = Markbridge::Parsers::BBCode::HandlerRegistry.default
handlers.overlay("quote") do |default|
  LoggingQuoteHandler.new(default:)
end
```

`overlay` is available on the BBCode, HTML, and TextFormatter `HandlerRegistry`. The yielded `default` is `nil` if nothing was previously registered. (MediaWiki's `InlineTagRegistry` has a different shape — see [Format guides → MediaWiki](/format-guides/mediawiki/).)

When several tag names share one AST class (e.g. `url`/`link`/`iurl` all build `AST::Url`), the wrapper has to be a *single* instance so the closing strategy's element-to-handler lookup matches on both sides. Use plain `register` for that, not `overlay`:

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

When you're extending Markbridge to feed a Discourse migration — links to be resolved later, uploads to be tracked, mentions to be looked up — the same triad applies. The renderer Tag stays a pure formatter that returns the placeholder string; the importer reads the placeholder nodes back off `conversion.ast.descendants(...)` afterwards. See [Migrating to Discourse → Placeholders](/migrating/placeholders/).

## When to customize vs. fork

- **Unknown tag** in input → register a handler.
- **Known tag, different output** → pass `tags: { ASTClass => MyTag.new }` to `discourse_renderer`.
- **Wrap default behavior** → `HandlerRegistry#overlay` for parser-side; `tags:` overrides for renderer-side.
- **New output format** (not Discourse Markdown) → write a new renderer that walks the AST. The parsers and AST are renderer-agnostic.

See [`examples/`](https://github.com/discourse/markbridge/tree/main/examples) for working versions of all of these.
