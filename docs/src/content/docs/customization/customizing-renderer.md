---
title: Customizing the renderer
description: Build a reusable Discourse renderer with Markbridge.discourse_renderer — override tags, drop tags, swap escapers, post-process output.
---

The Discourse renderer is configurable through a single factory: `Markbridge.discourse_renderer`. Build a `Renderer` once with the customizations you need, then pass it to as many `*_to_markdown` calls as you like via the `renderer:` kwarg.

<!-- spec:before
MyPlaceholderUrlTag = Class.new(Markbridge::Renderers::Discourse::Tag) do
  def render(element, interface) = interface.render_children(element)
end
def write_markdown(_post, _markdown); end
posts = [Struct.new(:body).new("[b]hi[/b]")]
-->
```ruby
RENDERER = Markbridge.discourse_renderer(
  tags: { Markbridge::AST::Url => MyPlaceholderUrlTag.new },
  unregister: [Markbridge::AST::Color, Markbridge::AST::Size],
  escape_hard_line_breaks: true,
)

posts.each do |post|
  result = Markbridge.bbcode_to_markdown(post.body, renderer: RENDERER)
  write_markdown(post, result.markdown)
end
```

The renderer is safe to reuse across thousands of posts. It holds no per-post state, so nothing leaks between posts — you collect any side data per call by walking `result.ast`.

## The factory

```ruby
Markbridge.discourse_renderer(
  tags: nil,                         # Hash{Class => Tag, nil}
  tag_library: nil,                  # starting library
  unregister: nil,                   # Array<Class> to drop
  escaper: nil,                      # custom MarkdownEscaper
  escape_hard_line_breaks: false,    # sugar for the default escaper
  allow: nil,                        # Symbol/Array<Symbol> — markers to leave unescaped
  escape: true,                      # false swaps in IdentityEscaper (no escaping)
  postprocessor: nil,                # custom Postprocessor instance
)
```

Every kwarg is optional. The defaults give you the standard Discourse renderer.

### `tags:` — override or add Tags

`tags:` is a hash of AST class → `Tag` instance. Mappings merge on top of the default `TagLibrary`, so unmapped classes keep their default rendering.

<!-- spec:before
MyBoldTag = MyPlaceholderUrlTag = Class.new(Markbridge::Renderers::Discourse::Tag) do
  def render(element, interface) = interface.render_children(element)
end
-->
```ruby
Markbridge.discourse_renderer(
  tags: {
    Markbridge::AST::Bold => MyBoldTag.new,
    Markbridge::AST::Url  => MyPlaceholderUrlTag.new,
  }
)
```

Map a class to `nil` to unregister it (same as listing it under `unregister:`).

### `unregister:` — drop AST classes

Listed AST classes fall through to `render_children`, which renders only their text content with surrounding markup discarded. Useful when the source format has tags you want to ignore (sizing, color) without writing pass-through Tags.

```ruby
Markbridge.discourse_renderer(
  unregister: [Markbridge::AST::Color, Markbridge::AST::Size, Markbridge::AST::Underline]
)
```

### `escape_hard_line_breaks:` — strip trailing-space line breaks

In Markdown, a line ending in two or more trailing spaces becomes a hard break (`<br>`). When source content happens to carry that whitespace, the result can surprise readers.

```ruby
Markbridge.discourse_renderer(escape_hard_line_breaks: true)
# Strips "  \n" → "\n" before escaping; no <br>.
```

The default (`false`) preserves trailing spaces and lets the downstream Markdown renderer decide.

### `escaper:` — full escaper replacement

For control beyond the hard-line-breaks toggle, pass your own `MarkdownEscaper` (or subclass). Mutually exclusive with `escape_hard_line_breaks:` — if you supply an escaper, the boolean is ignored.

```ruby
class ListPermissiveEscaper < Markbridge::Renderers::Discourse::MarkdownEscaper
  # Allow leading "- " through unescaped so importer-supplied lists survive.
  def escape(text, context: nil)
    return text if text.match?(/\A- /)
    super
  end
end

Markbridge.discourse_renderer(escaper: ListPermissiveEscaper.new)
```

### `allow:` — let specific Markdown markers through

By default the escaper escapes Markdown found in source text, so a literal `- ` or `1.` from a forum post doesn't accidentally turn into a list. If the source *does* use real Markdown lists you want to keep, allow those markers instead of subclassing the escaper:

```ruby
Markbridge.discourse_renderer(allow: :lists)
```

The keys are `:bullet_list`, `:ordered_list`, `:atx_heading`, and `:block_quote`, plus the alias `:lists` (bullet + ordered). An unknown key raises `ArgumentError`. Thematic breaks (`---`, `***`) and setext underlines (`===`) stay escaped — `allow:` opens up specific markers, not the whole escaper. It builds on the default escaper, so don't combine it with a custom `escaper:`.

### `escape:` — turn escaping off entirely

When the source is already trusted Markdown, skip escaping altogether:

```ruby
Markbridge.discourse_renderer(escape: false)
```

This swaps in `Markbridge::Renderers::Discourse::IdentityEscaper`, which returns text unchanged. `escape: false` can't be combined with `escape_hard_line_breaks:` or `allow:` (those configure the normal escaper, which `escape: false` replaces); an explicit `escaper:` always wins. To skip escaping for a single node rather than the whole document, use `AST::MarkdownText`.

### `postprocessor:` — clean up the final string

After all Tags have rendered, the output runs through a `Postprocessor` that collapses multi-blank-line runs, strips whitespace-only lines, and trims document edges. Subclass `Markbridge::Renderers::Discourse::Postprocessor` and override `#call` to change that.

```ruby
class StripDoubleSpaces < Markbridge::Renderers::Discourse::Postprocessor
  def call(text)
    super.gsub(/(?<=\S)  +(?=\S)/, " ")
  end
end

Markbridge.discourse_renderer(postprocessor: StripDoubleSpaces.new)
```

Pass the bare base class (`Postprocessor.new`) to keep the default cleanup; pass a no-op (`->(s) { s }` won't work — it must respond to `#call(text)`) if you want raw output.

## Build once, reuse everywhere

The renderer carries no per-post state: every top-level `*_to_markdown` call produces its own `Conversion`. Constructing a renderer is cheap; constructing thousands is wasteful. The build-once pattern is the recommended shape:

```ruby
class ForumImporter
  RENDERER = Markbridge.discourse_renderer(
    tags: {},          # your custom Tags
    unregister: [],    # AST classes to drop
    escape_hard_line_breaks: true,
  )

  def import(post)
    result = Markbridge.bbcode_to_markdown(post.body, renderer: RENDERER)
    persist(post, result.markdown)
  end
end
```

There is no per-process default renderer — pass `renderer:` explicitly or let the convenience methods build a fresh default each call.

## Coming from `Markbridge.configure`

Markbridge no longer exposes a global `Markbridge.configuration` or `Markbridge.configure` block. Every customization moves into a renderer.

| Old | New |
|-----|-----|
| `Markbridge.configure { \|c\| c.escape_hard_line_breaks = true }` | `Markbridge.discourse_renderer(escape_hard_line_breaks: true)` |
| `Markbridge.default_tag_library.register(klass, tag)` | `Markbridge.discourse_renderer(tags: { klass => tag })` |
| `Markbridge.reset_defaults!` | (not needed — every call builds fresh unless you pass `renderer:`) |

Per-call `tag_library:` and `escaper:` kwargs on `*_to_markdown` are also gone; they all flow through `renderer:`.

## See also

- [Migrating to Discourse → Overview](/migrating/overview/) — when this page's customizations show up in a real importer.
- [Extending Markbridge](/customization/extending/) — how to write the custom Tags and handlers you'd register here.
- [Reference → Upgrading](/reference/upgrading/) — the full break list from the previous API.
