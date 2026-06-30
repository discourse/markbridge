---
title: Full example
description: One small forum importer that uses every customization path — custom AST, handler wrapping, placeholder Tags, a custom escaper, and per-post failure isolation.
---

This page is one small importer that uses every customization Markbridge offers, all at once. It's the same code as [`examples/forum_migration.rb`](https://github.com/discourse/markbridge/blob/main/examples/forum_migration.rb) in the repo — copy it into a file, run it with `bundle exec ruby`, and you should get the output shown below.

It packs a lot into a few posts:

- A custom AST node and handler for a tag the defaults don't know (`[font=courier]`).
- A wrapper around the default URL handler (here it just delegates; a real importer would log).
- A custom Tag that turns internal links into placeholder strings to resolve later.
- `Markbridge.discourse_renderer(...)` with a `tags:` map, an `unregister:` list, and a custom escaper.
- `Markbridge.convert(input, format:)` handling BBCode and HTML in the same loop.
- `raise_on_error: false`, so one broken post doesn't take down the whole run.
- Collecting the placeholders afterwards by walking `Conversion#ast`, plus reading `Conversion#unknown_tags`.

It's a lot for four posts — but every line maps to something a real migration runs into.

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

# -- Custom URL Tag producing placeholder strings ---------------------------

# Internal links → opaque, deterministic placeholders the importer
# resolves later. External links → normal Markdown. The Tag is a pure
# function of its element: the placeholder is derived from the href, so
# no render-time state and nothing to "emit" — the importer collects the
# internal links afterwards by walking the AST (see the loop below).
INTERNAL_HOST = "https://forum.example.com/"

class PlaceholderUrlTag < Markbridge::Renderers::Discourse::Tag
  def render(element, interface)
    href = element.href
    text = interface.render_children(element, context: interface.with_parent(element))

    if PlaceholderUrlTag.internal?(href)
      PlaceholderUrlTag.placeholder_for(href)
    else
      "[#{text}](#{href})"
    end
  end

  def self.internal?(href)
    href&.start_with?(INTERNAL_HOST)
  end

  # Derive a stable token from the source path: t/42, u/alice, …
  def self.placeholder_for(href)
    "[[link:#{href.delete_prefix(INTERNAL_HOST)}]]"
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
internal_links = []

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

  # Collect the internal links the renderer turned into placeholders, by
  # walking the AST that produced this post's Markdown. No side channel:
  # the Url nodes are still in the tree, each carrying its source href.
  result.ast.descendants(Markbridge::AST::Url).each do |url|
    next unless PlaceholderUrlTag.internal?(url.href)
    internal_links << { url: url.href, placeholder: PlaceholderUrlTag.placeholder_for(url.href) }
  end

  puts "post ##{post[:id]} (#{post[:format]}): #{result.markdown.inspect}"
  puts "  unknown_tags: #{result.unknown_tags}" if result.unknown_tags.any?
end

puts
puts "Migration complete:"
puts "  ok: #{stats[:ok]}"
puts "  errors: #{stats[:errors]}"
puts "  link placeholders collected: #{internal_links.size}"
internal_links.each { |l| puts "    #{l[:placeholder]} -> #{l[:url]}" }
```

## Expected output

```
post #1 (bbcode): "**hello** world `code`"
post #2 (bbcode): "see [[link:t/42]] and [ext](https://example.org)"
post #3 (bbcode): "hello"
  unknown_tags: {"unknownext" => 2}
post #4 (html): "**html** [[link:u/alice]]"

Migration complete:
  ok: 4
  errors: 0
  link placeholders collected: 2
    [[link:t/42]] -> https://forum.example.com/t/42
    [[link:u/alice]] -> https://forum.example.com/u/alice
```

## What's worth a closer look

The script is commented, so here are only the parts that tend to surprise people. The matching pages go deeper on each.

- **The placeholder Tag returns a plain string and remembers nothing.** `PlaceholderUrlTag` turns external links into normal Markdown and internal ones into `[[link:t/42]]`. The same href always gives the same string, so you don't store anything during rendering — you walk `result.ast.descendants(Markbridge::AST::Url)` afterwards and rebuild the list. The tree is your record. ([Placeholders](/migrating/placeholders/))
- **The placeholder is copied into the output exactly as written.** Markdown escaping only touches text from the source, never a Tag's return value — so the `[` and `]` in `[[link:t/42]]` survive untouched. ([Placeholders → Placeholder strings pass through verbatim](/migrating/placeholders/#placeholder-strings-pass-through-verbatim))
- **`url`, `link`, and `iurl` share one handler instance.** They all build `AST::Url`, and that one instance has to be shared — using `overlay` here would create three separate wrappers and break tag closing. ([Extending → Wrapping a default handler](/customization/extending/#wrapping-a-default-handler))
- **`unregister:` keeps the text but drops the formatting.** `Color`, `Size`, and `Underline` disappear, but their inner text renders straight through — handy when the old forum used them just for decoration.
- **`Markbridge.convert(input, format:)` handles mixed formats in one loop.** If every post is the same format, reach for `bbcode_to_markdown` (etc.) instead — `convert` earns its keep only when the format changes row to row.
- **`raise_on_error: false` keeps one bad post from sinking the run.** Errors land on `result.errors` instead of raising. Keep the default (`true`) in tests so real bugs still shout at you; flip it for the production import.

A quick cheat sheet for what comes back:

```ruby
result.markdown                                  # the rendered Markdown
result.unknown_tags                              # Hash{String => Integer}
result.ast.descendants(Markbridge::AST::Url)     # link nodes, for collecting placeholders
result.errors                                    # filled only when raise_on_error: false caught one
```

Two small things: `unknown_tags` counts the opening *and* closing tag, so `[unknownext]hi[/unknownext]` shows up as `2`, not `1`. And `descendants(klass)` returns `[]` (never `nil`) when nothing matches, so you can skip the nil-checks.

## Where next

- [Placeholders](/migrating/placeholders/) — the AST node, handler, and Tag in detail.
- [Customizing the renderer](/customization/customizing-renderer/) — every option of `discourse_renderer`.
- [Extending Markbridge](/customization/extending/) — handlers, Tags, and `HandlerRegistry#overlay`.
- [Reference → Upgrading](/reference/upgrading/) — if you're coming from an older Markbridge version.
