---
title: Upgrading
description: Breaking-change notes between Markbridge releases.
---

## 0.3.1 — AST normalization runs by default

A new `Markbridge::Normalizer` pass runs between the parse-time `yield` hook and rendering, and it's **on by default** for every `*_to_markdown` call, `convert`, and `render`. It rewrites nesting that Markdown can't express, so you may see different output with no code change on your side:

- A link inside a link collapses to a single link (CommonMark forbids nested links).
- A block element inside an inline container — a quote, list, table, or a `Poll`/`Event` inside a link, bold, or a heading — is moved out, so the inline element doesn't break.
- A fenced or multi-line code block inside an inline container is moved out; a one-line code span stays.
- A formatting wrapper left empty by the above is removed (no stray `**` `**`).

Every change is reported under `conversion.diagnostics[:normalization]`, next to `unknown_tags`. The default rules are legality only — Discourse policy like moving an image out of a link isn't built in; add those rules yourself. To turn the pass off, pass `normalize: false`. See [AST normalization](/concepts/normalization/) for the full picture.

## 0.3.0 — breaking changes

### `AST::Quote` attribution fields renamed and typed

`post` and `topic` are gone. The fields now say what they hold, and every id is an `Integer` (it used to be a `String`):

```rb
# Before
quote.post    # => "123"  (called "post ID", but actually a post *number*)
quote.topic   # => "456"

# After
quote.post_number  # => 123   position within the topic (Discourse quotes)
quote.topic_id     # => 456
quote.post_id      # => 9001  database id (phpBB / XenForo-style sources)
quote.user_id      # => 12    new — id-based user attribution
```

The TextFormatter parser no longer funnels phpBB's `post_id` into a rendered `post:N` attribution — a database id there links the wrong post. Id-attributed quotes now render name-only (`[quote="alice"]`) and carry `post_id` / `user_id` on the AST for you to remap, typically in the block yielded between parse and render.

### Bare and relative URLs render differently

- A **bare URL** — link text equal to the href, or no text — renders as the plain href instead of `[url](url)`, so Discourse can autolink and onebox it. `AST::Url#bare?` exposes the same judgment.
- **Relative hrefs** (`/t/5`, `#anchor`, wiki page names) are kept as links instead of being dropped. Unknown schemes (`javascript:` and friends) are still removed. Destinations containing whitespace use the `<…>` CommonMark form.
- A text-less link no longer renders as `[](url)`.

### Custom tags must return a String

A tag that returns `nil` (or anything other than a String) now raises a descriptive `TypeError` right away, instead of failing later inside string concatenation. To override only some nodes and keep the stock rendering for the rest, use the new fall-through:

```ruby
Markbridge::Renderers::Discourse::Tag.new do |node, interface|
  next interface.render_default(node) unless node.href&.start_with?("/")
  "[internal|#{node.href}]"
end
```

`interface.render_default(node)` renders the node with its stock Tag, bypassing your override — so a custom Tag can intercept just the cases it cares about and defer the rest.

## 0.2.0 — breaking changes

0.2.0 reshapes the top-level API around `Conversion`/`Parse` result types and a single `renderer:` kwarg for render-side customization. There is no backwards-compatibility shim — the changes are mechanical, but every call site needs to be updated.

### Convenience methods now return a `Conversion`, not a `String`

```rb
# Before
markdown = Markbridge.bbcode_to_markdown(input)
markdown.gsub(/.../, "...")           # String operation

# After
result = Markbridge.bbcode_to_markdown(input)
result.markdown.gsub(/.../, "...")    # explicit access

# Or, if you only need the string for puts/interpolation:
puts result                           # to_s delegates to markdown
"got #{result}"                       # works
```

`Conversion` carries `markdown`, `ast`, `format`, `unknown_tags`, `diagnostics`, `errors`. It does *not* delegate other String methods — `result.gsub(...)` raises `NoMethodError`. Use `result.markdown.gsub(...)`.

### Singleton config and per-process default registries are gone

Removed:

- `Markbridge.configuration`
- `Markbridge.configure { |c| c.escape_hard_line_breaks = ... }`
- `Markbridge.reset_defaults!`
- `Markbridge.default_handlers`
- `Markbridge.default_html_handlers`
- `Markbridge.default_text_formatter_handlers`
- `Markbridge.default_tag_library`
- `Markbridge::Configuration` (the class)

To customize rendering, build a `Renderer` once via the new factory and pass it through `renderer:`:

```rb
# Before
Markbridge.configure { |c| c.escape_hard_line_breaks = true }
Markbridge.default_tag_library.register(MyAst::Bold, MyTag.new)
Markbridge.bbcode_to_markdown(input)

# After
RENDERER =
  Markbridge.discourse_renderer(
    tags: { MyAst::Bold => MyTag.new },
    escape_hard_line_breaks: true,
  )
Markbridge.bbcode_to_markdown(input, renderer: RENDERER)
```

Build the renderer once outside your migration loop and reuse it across thousands of posts; it holds no per-post state. See [Customizing the renderer](/customization/customizing-renderer/) for the full set of factory kwargs.

### `tags:`, `tag_library:`, `escaper:`, `escape_hard_line_breaks:` removed from per-call signature

All four moved into `Markbridge.discourse_renderer(...)`. The four `*_to_markdown` methods plus `Markbridge.convert` now accept only:

- `handlers:` — parser handler registry
- `renderer:` — pre-built Renderer
- `raise_on_error:` — boolean (default `true`)

### MediaWiki kwarg renamed: `inline_tag_registry:` → `handlers:`

```rb
# Before
Markbridge.parse_mediawiki(input, inline_tag_registry: my_registry)
Markbridge::Parsers::MediaWiki::Parser.new(inline_tag_registry: my_registry)

# After
Markbridge.parse_mediawiki(input, handlers: my_registry)
Markbridge::Parsers::MediaWiki::Parser.new(handlers: my_registry)
```

The accepted *type* is unchanged — still an `InlineTagRegistry`. Only the parameter name moves, for parity with the BBCode/HTML/TextFormatter parsers.

### TextFormatter handlers must accept `processor:`

`Parsers::TextFormatter::Handlers::BaseHandler#process` now has a three-arg signature:

```rb
# Before
def process(element:, parent:)

# After
def process(element:, parent:, processor: nil)
```

Update every custom subclass under your importer's TextFormatter handler tree. The `processor:` argument is the parser instance and exposes `process_children(xml_element, ast_node)` for handlers that recurse into children manually.

Proc/lambda handlers are no longer accepted — a handler must be an object responding to `#process(...)`. Wrap any one-off lambda in a small handler class with a `#process` method.

### Tag side-data: read it back off the AST instead of mutating ctor-injected hashes

Placeholder Tags used to record side data by mutating a hash injected through the constructor (and a short-lived draft used an `interface.emit` buffer). Both are gone. A Tag is now a pure function of its element — it returns a string and records nothing; the importer collects side data by walking `conversion.ast` afterwards:

```ruby
# Before
class UrlTag < Markbridge::Renderers::Discourse::Tag
  def initialize(placeholders:)
    @placeholders = placeholders
  end

  def render(element, _interface)
    link = build_link(element)
    @placeholders[:links] << link        # mutates ctor-injected array
    link[:placeholder]
  end
end
# Importer pre-allocates @placeholders, passes to Tag, reads it after.

# After
class UrlTag < Markbridge::Renderers::Discourse::Tag
  def render(element, _interface)
    build_link(element)[:placeholder]    # pure: returns a string, records nothing
  end
end
# Importer reads back: result.ast.descendants(InternalLink).each { |node| ... }
```

The resolved value the importer needs lives on the custom AST node (pinned at parse time by the handler, or read off the source-side data the Tag already has). Pure lookup tables (`uploads:`, `repository:`) injected into Tag constructors are still fine — they're read-only. Only *mutation during render* moves out, to a walk over `conversion.ast.descendants(...)`. See [Placeholders](/migrating/placeholders/).

### `RawHandler` no longer requires `language:` on the AST class

`Markbridge::Parsers::BBCode::Handlers::RawHandler` used to call `@element_class.new(language:)` unconditionally. Custom AST classes reused with `RawHandler` had to declare a `language:` kwarg even when unused. The handler now introspects the AST class once and only passes `language:` when the class accepts it. No code action needed unless you'd previously added a dummy `def initialize(language: nil); super(); end` just to satisfy the handler — you can remove it.

### Per-row failure isolation

For migration loops, set `raise_on_error: false` to surface render exceptions on `Conversion#errors` instead of crashing the loop:

<!-- spec:before
RENDERER = Markbridge.discourse_renderer
def log_failure(_post, _errors); end
def write_markdown(_post, _markdown); end
posts = [Struct.new(:body).new("[b]hi[/b]")]
-->
```ruby
posts.each do |post|
  result = Markbridge.bbcode_to_markdown(post.body, renderer: RENDERER, raise_on_error: false)
  if result.errors.any?
    log_failure(post, result.errors)
  else
    write_markdown(post, result.markdown)
  end
end
```

The default remains `raise_on_error: true`, preserving the prior behavior of letting exceptions propagate.

## 0.2.0 — new capabilities

0.2.0 also added a few things you'll likely want during a migration.

### Let some Markdown markers through with `allow:`

If your source posts already contain `- item` or `1. item` lists you want to keep, you no longer need to subclass the escaper. Before, you'd write a whole class:

```ruby
class ListPermissiveEscaper < Markbridge::Renderers::Discourse::MarkdownEscaper
  private

  def escape_block_level(content, prev_was_paragraph)
    case content.getbyte(0)
    when 0x2D, 0x2A, 0x2B then return content, false if content.match?(/\A[-*+]\s/)
    when 0x30..0x39       then return content, false if content.match?(/\A\d+[.)]\s/)
    end
    super
  end
end
Markbridge.discourse_renderer(escaper: ListPermissiveEscaper.new)
```

Now it's one keyword:

```ruby
Markbridge.discourse_renderer(allow: :lists)
```

The keys are `:bullet_list`, `:ordered_list`, `:atx_heading`, and `:block_quote`, plus the alias `:lists` (bullet + ordered). An unknown key raises `ArgumentError`. Thematic breaks (`---`, `***`) and setext underlines (`===`) are still escaped — `allow:` opens up specific markers, not the whole escaper.

### Turn escaping off completely with `escape: false`

When the source is already trusted Markdown, skip escaping entirely:

<!-- spec:before
input = "already **trusted** markdown"
-->
```ruby
no_escape = Markbridge.discourse_renderer(escape: false)
Markbridge.bbcode_to_markdown(input, renderer: no_escape)
```

This swaps in `Markbridge::Renderers::Discourse::IdentityEscaper`, a tiny class whose `escape` returns the text unchanged. `escape: false` can't be combined with `escape_hard_line_breaks:` or `allow:` (those configure the normal escaper, which `escape: false` replaces). An explicit `escaper:` always wins. For a single node rather than the whole document, `AST::MarkdownText` already skips the escaper for that node only.

### Change the AST between parse and render

You can edit the parsed tree before it's rendered — handy for adding attachments that weren't in the post body. Every `*_to_markdown` / `convert` method takes a block, or you can render a `Parse` by hand:

<!-- spec:before
class OrphanAttachment < Markbridge::AST::Node
  attr_reader :source_id
  def initialize(source_id:)
    super()
    @source_id = source_id
  end
end
class OrphanAttachmentTag < Markbridge::Renderers::Discourse::Tag
  def render(element, _interface) = "[upload|#{element.source_id}]"
end
RENDERER = Markbridge.discourse_renderer(tags: { OrphanAttachment => OrphanAttachmentTag.new })
input = "see attached"
attachments = [Struct.new(:id).new(42)]
-->
```ruby
# Block form — edit the AST inline
Markbridge.bbcode_to_markdown(input, renderer: RENDERER) do |ast|
  attachments.each { |a| ast << OrphanAttachment.new(source_id: a.id) }
end

# Or render a Parse you've already changed
parse = Markbridge.parse_bbcode(input)
parse.ast << OrphanAttachment.new(source_id: 7)
result = Markbridge.render(parse, renderer: RENDERER)
```

`Markbridge.render` takes either a `Parse` (preferred — it keeps `unknown_tags`, `diagnostics`, and the source `format`) or a bare AST node (those fields default to empty, and `format` is `nil` since there was no source). A non-`Document` node is wrapped in one, so `Conversion#ast` is always a `Document`. Your changes stay in `Conversion#ast`.

### Pass a Nokogiri tree to the HTML and TextFormatter parsers

Both Nokogiri-backed parsers now accept a `String` *or* a parsed Nokogiri node. If your importer already runs its own DOM pass, hand the live tree straight over — no serialize-and-reparse in between:

<!-- spec:before
html = "<p>hello <b>world</b></p>"
-->
```ruby
fragment = Nokogiri::HTML.fragment(html)
Markbridge.html_to_markdown(fragment)
```

Same idea for TextFormatter XML:

<!-- spec:before
xml = "<r>hello</r>"
-->
```ruby
xml_doc = Nokogiri.XML(xml)
Markbridge.text_formatter_xml_to_markdown(xml_doc)
```

A full `Nokogiri::HTML::Document` is unwrapped to its `<body>` children (so the synthetic `<html>`/`<head>`/`<body>` don't show up in `unknown_tags`); a fragment or bare element iterates its own children. For TextFormatter, an XML `Document` is unwrapped via `#root` (the single `<r>`/`<t>` element). Skipping the round-trip also avoids a quirk where re-serializing percent-encodes non-ASCII bytes in URLs.

### Walk and edit the tree with helpers on `Element`

Three methods replace the hand-rolled recursion importers used to write:

<!-- spec:before
doc = Markbridge::AST::Document.new
doc << Markbridge::AST::Bold.new.tap { |b| b << Markbridge::AST::Text.new("hi") }
-->
```ruby
# Walk every descendant, depth-first
doc.each_descendant { |node| node }

# Filter by class (uses is_a?, so abstract bases match subclasses)
bold = doc.descendants(Markbridge::AST::Bold).first

# Swap a direct child in place, keeping its position
doc.replace_child(bold, Markbridge::AST::Text.new("HI"))
```

`each_descendant` snapshots each element's children when it reaches them, so calling `replace_child` mid-walk is safe and nodes appended during the walk aren't re-visited.

### `AST::Details` for collapsible sections

Discourse's collapsible `[details=…]…[/details]` block is now a built-in AST node with an auto-registered Tag, so you can drop any local `DetailsBlock` shim:

<!-- spec:before
doc = Markbridge::AST::Document.new
-->
```ruby
doc << Markbridge::AST::Details.new(title: "Signature").tap do |block|
  block << Markbridge::AST::Text.new("--\nAlex Doe")
end
Markbridge.render(doc).markdown
```

`title` is optional — leave it out for a bare `[details]` (and `<summary>Summary</summary>` in HTML mode). The title is HTML-escaped in the `<summary>`.

## See also

- [Customizing the renderer](/customization/customizing-renderer/) — full reference for the factory.
- [Extending Markbridge](/customization/extending/) — adding custom tags and handlers.
