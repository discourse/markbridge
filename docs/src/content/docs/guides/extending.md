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

### 5. Register the renderer tag

```ruby
tag_library = Markbridge::Renderers::Discourse::TagLibrary.default
tag_library.register(Markbridge::AST::Callout, callout_tag)
```

### 6. Use it

```ruby
Markbridge.bbcode_to_markdown(
  "[callout=warning]Heads up![/callout]",
  handlers:,
  tag_library:,
)
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

Use `find_parent` / `has_parent?` to render differently inside specific ancestors (e.g. a code span inside a table cell).

## HTML and TextFormatter parsers

Both use a simpler, stateless handler API. A handler is any callable accepting `(element:, parent:)`. Return the node you want children to recurse into, or `nil` to skip them.

```ruby
html_handlers =
  Markbridge::Parsers::HTML::HandlerRegistry.build_from_default do |registry|
    registry.register("details", ->(element:, parent:) {
      spoiler = Markbridge::AST::Spoiler.new
      parent << spoiler
      spoiler
    })
  end

Markbridge.html_to_markdown(input, handlers: html_handlers)
```

The TextFormatter registry works the same way, but element names are **UPPERCASE** per s9e convention.

## Replacing a built-in renderer tag

You don't need a new AST node — you can re-render an existing one however you like:

```ruby
tag_library = Markbridge::Renderers::Discourse::TagLibrary.default

tag_library.register(
  Markbridge::AST::Url,
  Markbridge::Renderers::Discourse::Tag.new do |element, interface|
    # Custom link rendering — e.g., prefix internal links
    href = element.href.start_with?("/") ? "https://forum.example.com#{element.href}" : element.href
    "[#{interface.render_children(element)}](#{href})"
  end,
)
```

## Convention-based auto-registration

The Discourse renderer can discover its own built-in tags by naming convention:

```ruby
tag_library = Markbridge::Renderers::Discourse::TagLibrary.new
tag_library.auto_register!
# Discovers BoldTag → AST::Bold, ItalicTag → AST::Italic, etc.
```

`auto_register!` only walks `Markbridge::Renderers::Discourse::Tags::*`, so consumer-defined tag classes aren't picked up automatically — register those explicitly with `tag_library.register(MyAst, MyTag.new)`.

## When to customize vs. fork

- **Unknown tag** in input → register a handler.
- **Known tag, different output** → register a new renderer tag for the same AST node.
- **New output format** (not Discourse Markdown) → write a new renderer that walks the AST — the parsers and AST are renderer-agnostic.

See [`examples/`](https://github.com/discourse/markbridge/tree/main/examples) for working versions of all of these.
