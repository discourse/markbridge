---
title: Full walkthrough
description: An end-to-end forum migration touching every customization path — custom AST, handler delegation, placeholder Tags, custom escaper, and per-post failure isolation.
---

This page walks through a runnable mini-importer that exercises every customization Markbridge offers. It mirrors `examples/forum_migration.rb` in the gem repository — copy it into a script, `bundle exec ruby` it, and the output should match.

What it demonstrates:

- A custom AST node + parser handler for a tag the default registry doesn't cover (`[font=courier]`).
- Handler delegation via `HandlerRegistry#overlay` — wrap the default URL handler with a logging-style decorator.
- A custom Tag that emits side data with `interface.emit` for the importer to pick up.
- `Markbridge.discourse_renderer(...)` with a `tags:` override map, an `unregister:` list, and a custom escaper subclass.
- `Markbridge.convert(input, format:)` dispatching across BBCode and HTML in one loop.
- `raise_on_error: false` collecting per-post failures instead of crashing.
- Reading `Conversion#emitted(:link)` and `Conversion#unknown_tags` post-render.

## The full script

```ruby
require "bundler/setup"
require "markbridge/all"

# -- Custom AST + handler ----------------------------------------------------

# AST node for [font=courier]…[/font].
class FontNode < Markbridge::AST::Element
  attr_reader :font

  def initialize(font: nil)
    super()
    @font = font
  end
end

class FontHandler < Markbridge::Parsers::BBCode::Handlers::BaseHandler
  def initialize
    @element_class = FontNode
  end

  def on_open(token:, context:, registry:, tokens: nil)
    font = token.attrs[:font] || token.attrs[:option]
    context.push(FontNode.new(font:), token:)
  end

  def auto_closeable? = true
  attr_reader :element_class
end

# Renderer Tag: monospace fonts → inline code; other fonts pass through.
FONT_TAG =
  Markbridge::Renderers::Discourse::Tag.new do |element, interface|
    child_context = interface.with_parent(element)
    content = interface.render_children(element, context: child_context)

    if element.font&.match?(/\b(courier|monospace|consolas|menlo|monaco)\b/i)
      "`#{content.strip}`"
    else
      content
    end
  end

# -- Custom URL Tag emitting placeholder records ----------------------------

# Internal links → opaque placeholders the importer resolves later.
# External links → normal Markdown.
class PlaceholderUrlTag < Markbridge::Renderers::Discourse::Tag
  def render(element, interface)
    href = element.href
    text = interface.render_children(element, context: interface.with_parent(element))

    if internal_link?(href)
      placeholder = "[[link:#{next_id}]]"
      interface.emit(:link, { url: href, text:, placeholder: })
      placeholder
    else
      "[#{text}](#{href})"
    end
  end

  private

  def internal_link?(href)
    href&.start_with?("https://forum.example.com/")
  end

  def next_id
    @counter ||= 0
    @counter += 1
  end
end

# -- Custom escaper that allows list markers through -------------------------

# Some forum corpora (e.g. Liferay) use "1. item" / "- item" Markdown
# inside posts. The default escaper would escape the markers; this
# subclass lets them through at block level.
class ListPermissiveEscaper < Markbridge::Renderers::Discourse::MarkdownEscaper
  private

  def escape_block_level(content, prev_was_paragraph)
    case content.getbyte(0)
    when 0x2D, 0x2A, 0x2B # '-', '*', '+'
      return content, false if content.match?(/\A[-*+]\s/)
    when 0x30..0x39
      return content, false if content.match?(/\A\d+[.)]\s/)
    end
    super
  end
end

# -- Wrap a default handler --------------------------------------------------

class LoggingUrlHandler < Markbridge::Parsers::BBCode::Handlers::BaseHandler
  def initialize(default:)
    @default = default
    @element_class = default.element_class
  end

  def on_open(token:, context:, registry:, tokens: nil)
    # …real importer would log here; we just delegate.
    @default.on_open(token:, context:, registry:, tokens:)
  end

  attr_reader :element_class
end

# -- Build the importer's reusable parts -----------------------------------

HANDLERS =
  Markbridge::Parsers::BBCode::HandlerRegistry.build_from_default do |r|
    r.register("font", FontHandler.new)

    # url/link/iurl all build AST::Url, so the wrapper must be a single
    # instance shared across the names — see Customization → Extending.
    default_url = r["url"]
    r.register(%w[url link iurl], LoggingUrlHandler.new(default: default_url))
  end

RENDERER =
  Markbridge.discourse_renderer(
    tags: {
      Markbridge::AST::Url => PlaceholderUrlTag.new,
      FontNode => FONT_TAG,
    },
    # Drop decorative built-ins; let their children fall through.
    unregister: [Markbridge::AST::Color, Markbridge::AST::Size, Markbridge::AST::Underline],
    escaper: ListPermissiveEscaper.new,
  )

# -- Sample posts ---------------------------------------------------------

POSTS = [
  { id: 1, format: :bbcode,
    body: "[b]hello[/b] [color=red]world[/color] [font=courier]code[/font]" },
  { id: 2, format: :bbcode,
    body: "see [url=https://forum.example.com/t/42]this[/url] and [url=https://example.org]ext[/url]" },
  { id: 3, format: :bbcode,
    body: "[unknownext]hello[/unknownext]" },
  { id: 4, format: :html,
    body: "<b>html</b> <a href='https://forum.example.com/u/alice'>alice</a>" },
]

# -- The migration loop ---------------------------------------------------

stats = { ok: 0, errors: 0 }
emitted_links = []

POSTS.each do |post|
  result =
    Markbridge.convert(
      post[:body],
      format: post[:format],
      handlers: post[:format] == :bbcode ? HANDLERS : nil,
      renderer: RENDERER,
      raise_on_error: false,
    )

  if result.errors.any?
    stats[:errors] += 1
    puts "post ##{post[:id]} FAILED: #{result.errors.first.message}"
    next
  end

  stats[:ok] += 1
  emitted_links.concat(result.emitted(:link))

  puts "post ##{post[:id]} (#{post[:format]}): #{result.markdown.inspect}"
  puts "  unknown_tags: #{result.unknown_tags}" if result.unknown_tags.any?
end

puts
puts "Migration complete:"
puts "  ok: #{stats[:ok]}"
puts "  errors: #{stats[:errors]}"
puts "  link placeholders emitted: #{emitted_links.size}"
emitted_links.each { |l| puts "    #{l[:placeholder]} -> #{l[:url]}" }
```

## Expected output

```
post #1 (bbcode): "**hello** world `code`"
post #2 (bbcode): "see [[link:1]] and [ext](https://example.org)"
post #3 (bbcode): "hello"
  unknown_tags: {"unknownext" => 2}
post #4 (html): "**html** [[link:2]]"

Migration complete:
  ok: 4
  errors: 0
  link placeholders emitted: 2
    [[link:1]] -> https://forum.example.com/t/42
    [[link:2]] -> https://forum.example.com/u/alice
```

## Reading the script

### Custom AST + handler

`FontNode` carries the `font` attribute parsed from `[font=courier]`. `FontHandler` is a thin BBCode handler — its only job is to read the attribute and push the AST node. The default `on_close` from `BaseHandler` handles `[/font]`.

The pattern repeats for every source-format tag the default registry doesn't cover. See [Extending Markbridge](/customization/extending/) for the standalone walkthrough.

### Placeholder Tag with `interface.emit`

`PlaceholderUrlTag` overrides the default `UrlTag` for `AST::Url`. For external links it produces normal Markdown. For internal links — in this example, anything starting with `https://forum.example.com/` — it returns an opaque placeholder string and emits a record on the `:link` channel.

The placeholder string is whatever your importer parses cleanly downstream. `[[link:N]]` is one convention; pick another if it fits your tooling better. The string is spliced verbatim into the output — Markdown escaping never touches it (see [Placeholders → Placeholder strings pass through verbatim](/migrating/placeholders/#placeholder-strings-pass-through-verbatim)).

### Handler delegation via wrapping

`LoggingUrlHandler` is a wrapper around the default URL handler. The block in `HandlerRegistry.build_from_default` reads the default with `r["url"]` and registers the wrapper under all three URL aliases (`url`, `link`, `iurl`).

The reason this isn't using `overlay`: when one element class is registered under multiple aliases, the wrapper must be a *single* shared instance. `overlay` would call its block once per alias and create three different wrappers, breaking the closing strategy. See [Extending Markbridge → Wrapping a default handler](/customization/extending/#wrapping-a-default-handler) for the full reasoning.

### Renderer factory and `unregister:`

`Markbridge.discourse_renderer(...)` builds the reusable Renderer:

- `tags:` overrides `AST::Url` (placeholder behavior) and adds `FontNode` (the custom one).
- `unregister:` drops `Color`, `Size`, and `Underline` — the source forum used these decoratively, but the migrated Markdown shouldn't carry them. Their children render straight through (`render_children`), so the inner text survives.
- `escaper:` swaps in `ListPermissiveEscaper` so list markers in the source pass through to the output.

The renderer is built once outside the loop and reused for all four posts.

### `Markbridge.convert(input, format:)`

The migration loop handles BBCode and HTML in one pass. `Markbridge.convert` dispatches to the right `*_to_markdown` based on `format:`. The `handlers:` kwarg only matters for BBCode here (HTML uses its own default registry); we pass `nil` for HTML rows to skip it.

If your importer always handles one format, prefer the format-specific method (`bbcode_to_markdown`, etc.) — `convert` exists for the multi-format case.

### `raise_on_error: false` and per-post failure isolation

Render-time exceptions land on `Conversion#errors` instead of crashing the loop. The example treats any error as a per-post failure, logs it, and continues. The default `raise_on_error: true` is preferable in tests and during development; flip it for production migrations where one bad row shouldn't sink the rest.

### Reading the result

```ruby
result.markdown                # the rendered Markdown
result.unknown_tags            # Hash{String => Integer}
result.emitted(:link)          # what PlaceholderUrlTag emitted
result.errors                  # populated only when raise_on_error: false caught one
```

`result.unknown_tags` for post #3 (`[unknownext]hello[/unknownext]`) shows `{"unknownext" => 2}` — open + close tokens, both counted. The wrapper is dropped, the inner text survives.

`result.emitted(:link)` returns `[]` when nothing emitted on that channel — the convenience accessor avoids nil-checks. Loop-level accumulation just `concat`s these arrays.

## Where next

- [Placeholders](/migrating/placeholders/) — the triad pattern in detail.
- [Customizing the renderer](/customization/customizing-renderer/) — every kwarg of `discourse_renderer`.
- [Extending Markbridge](/customization/extending/) — handlers, Tags, and `HandlerRegistry#overlay`.
- [Reference → Upgrading](/reference/upgrading/) — for callers coming from the previous Markbridge API.
