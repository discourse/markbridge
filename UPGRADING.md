# Upgrading Markbridge

## 0.x — migration-API redesign

This release reshapes the top-level API around `Conversion`/`Parse`
result types and a single `renderer:` kwarg for render-side
customization. There is no backwards-compatibility shim — the changes
are mechanical but every importer call site needs to be updated.

### Convenience methods now return a `Conversion`, not a `String`

```ruby
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

`Conversion` carries `markdown`, `ast`, `format`, `unknown_tags`,
`diagnostics`, `emissions`, `errors`. It does *not* delegate other
String methods — `result.gsub(...)` will raise `NoMethodError`. Use
`result.markdown.gsub(...)`.

### Singleton config and per-process default registries are gone

The following are removed:

- `Markbridge.configuration`
- `Markbridge.configure { |c| c.escape_hard_line_breaks = ... }`
- `Markbridge.reset_defaults!`
- `Markbridge.default_handlers`
- `Markbridge.default_html_handlers`
- `Markbridge.default_text_formatter_handlers`
- `Markbridge.default_tag_library`
- `Markbridge::Configuration` (the class)

To customize rendering, build a `Renderer` once via the new factory
and pass it through `renderer:`:

```ruby
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

Build the renderer once outside your migration loop and reuse it
across thousands of posts.

### `tags:`, `tag_library:`, `escaper:`, `escape_hard_line_breaks:` removed from per-call signature

All four moved into `Markbridge.discourse_renderer(...)`. The four
`*_to_markdown` methods plus `Markbridge.convert` now accept only:

- `handlers:` — parser handler registry
- `renderer:` — pre-built Renderer
- `raise_on_error:` — boolean (default `true`)

### MediaWiki kwarg renamed: `inline_tag_registry:` → `handlers:`

```ruby
# Before
Markbridge.parse_mediawiki(input, inline_tag_registry: my_registry)
Markbridge::Parsers::MediaWiki::Parser.new(inline_tag_registry: my_registry)

# After
Markbridge.parse_mediawiki(input, handlers: my_registry)
Markbridge::Parsers::MediaWiki::Parser.new(handlers: my_registry)
```

The accepted *type* is unchanged — still an `InlineTagRegistry`. Only
the parameter name moves, for parity with the BBCode/HTML/TextFormatter
parsers.

### TextFormatter handlers must accept `processor:`

`Parsers::TextFormatter::Handlers::BaseHandler#process` now has a
three-arg signature:

```ruby
# Before
def process(element:, parent:)

# After
def process(element:, parent:, processor: nil)
```

Update every custom subclass under your importer's TextFormatter
handler tree. The `processor:` argument is the parser instance and
exposes `process_children(xml_element, ast_node)` for handlers that
want to recurse into children manually.

### Proc/lambda handlers no longer supported

Both HTML and TextFormatter previously accepted a `Proc`/lambda as a
handler. They now accept only objects responding to `#process(...)`.
Existing default handlers were already class-based; the only places
this affected built-in code were `<br>`/`<hr>` lambdas (now
`HTML::Handlers::SelfClosingHandler`) and the
`examples/custom_text_formatter_mappings.rb` lambdas (now Handler
classes).

Migration: define a tiny class extending the parser's `BaseHandler`
and move your lambda body into `#process(element:, parent:[, processor:])`.

```ruby
# Before
registry.register("HIGHLIGHT", ->(element:, parent:, processor:) {
  parent << HighlightNode.new(...)
  nil
})

# After
class HighlightHandler < Markbridge::Parsers::TextFormatter::Handlers::BaseHandler
  def initialize; @element_class = HighlightNode; end
  attr_reader :element_class

  def process(element:, parent:, processor:)
    parent << HighlightNode.new(...)
    nil
  end
end
registry.register("HIGHLIGHT", HighlightHandler.new)
```

The `BBCode` parser has always required class handlers (its
`on_open`/`on_close` lifecycle doesn't fit the lambda shape). All
three parsers now follow the same rule.

### Resolution lives in handlers, not Tags

The migration use case resolves placeholders (uploads, mentions,
internal links) at parse time via custom handler subclasses. The
handler stores the source-side reference in the converter's
upload/user/topic store, gets back a stable identifier, and pins
it on the AST node directly. Renderer Tags remain trivial output
formatting — no per-post state, no side-channel.

```ruby
# Custom AST node carrying the resolved id
class AttachmentPlaceholder < Markbridge::AST::Node
  attr_reader :upload_id
  def initialize(upload_id:); super(); @upload_id = upload_id; end
end

# Handler: resolves at parse, pins id on the node
class AttachmentHandler < Markbridge::Parsers::BBCode::Handlers::BaseHandler
  def initialize(uploads:); @uploads = uploads; end
  def on_open(token:, context:, registry:, tokens: nil)
    upload = @uploads.store_or_lookup(token.attrs[:option])
    context.add_child(AttachmentPlaceholder.new(upload_id: upload.id))
  end
  def element_class; AttachmentPlaceholder; end
end

# Tag: trivial output formatter, no state
class AttachmentTag < Markbridge::Renderers::Discourse::Tag
  def render(element, _interface) = "[upload|#{element.upload_id}]"
end

RENDERER = Markbridge.discourse_renderer(
  tags: { AttachmentPlaceholder => AttachmentTag.new },
)
```

`interface.emit` and `Conversion#emissions` (intermediate API in
earlier drafts of this redesign) are not part of the shipped API.
Resolution-aware base handlers belong in the converter framework
that wraps Markbridge; per-format converters (phpBB, vBulletin,
SMF, IPB attachment handlers) subclass them.

### `RawHandler` no longer requires `language:` on the AST class

`Markbridge::Parsers::BBCode::Handlers::RawHandler` used to call
`@element_class.new(language:)` unconditionally. Custom AST classes
reused with `RawHandler` had to declare a `language:` kwarg even when
unused. Now the handler introspects the AST class once and only passes
`language:` when the class accepts it. No code action needed unless
you'd previously added a dummy `def initialize(language: nil); super(); end`
just to satisfy the handler — you can remove it.

### Selective Markdown escaping (`allow:`)

Importers that want list markers (or other block-level constructs)
to survive escaping no longer need to subclass `MarkdownEscaper`:

```ruby
# Before
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
RENDERER = Markbridge.discourse_renderer(escaper: ListPermissiveEscaper.new)

# After
RENDERER = Markbridge.discourse_renderer(allow: :lists)
```

Recognised keys: `:bullet_list`, `:ordered_list`, `:atx_heading`,
`:block_quote`. Aliases: `:lists` → `[:bullet_list, :ordered_list]`.
Unknown keys raise `ArgumentError`. Thematic breaks (`---`, `***`)
and setext underlines (`===`) are still escaped — the kwarg
allow-lists specific block markers, not whole sections of the
escaper.

### Disabling Markdown escaping wholesale

For migration paths where the source content is already trusted
Markdown:

```ruby
NO_ESCAPE = Markbridge.discourse_renderer(escape: false)
Markbridge.bbcode_to_markdown(input, renderer: NO_ESCAPE)
```

Internally this swaps in `Markbridge::Renderers::Discourse::IdentityEscaper`
(a tiny `#escape(text) → text || ""` class). `escape: false` is
mutually exclusive with `escape_hard_line_breaks:` / `allow:` —
those configure `MarkdownEscaper`, which `escape: false` replaces
wholesale. An explicit `escaper:` always wins over either.

For *per-AST-node* opt-out, `AST::MarkdownText` already exists and
bypasses the escaper for that node only.

### Modifying the AST between parse and render

Two new shapes let you mutate the parsed AST before rendering, e.g.
to append attachments that weren't in the source post:

```ruby
# Block form on every *_to_markdown / convert method
Markbridge.bbcode_to_markdown(input, renderer: RENDERER) do |ast|
  attachments.each { |a| ast << OrphanAttachment.new(source_id: a.id) }
end

# Or pass a Parse explicitly to .render
parse = Markbridge.parse_bbcode(input)
parse.ast << OrphanAttachment.new(source_id: 7)
result = Markbridge.render(parse, renderer: RENDERER, raise_on_error: false)
# result.unknown_tags / .diagnostics / .format are preserved from the Parse.
```

`Markbridge.render` accepts either a `Parse` (preferred — preserves
`unknown_tags`/`diagnostics`/source `format`) or a bare AST node
(fields default to empty / `:discourse`). Mutations made between
parse and render persist in `Conversion#ast`.

### Per-row failure isolation

For migration loops, set `raise_on_error: false` to surface render
exceptions on `Conversion#errors` instead of crashing the loop:

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

The default is still `raise_on_error: true`, preserving the prior
behavior of letting exceptions propagate.

### HTML / TextFormatter parsers accept pre-parsed Nokogiri input

Both Nokogiri-backed parsers now take either a String *or* a
pre-parsed `Nokogiri::XML::Node`. Importers that already run their
own DOM preprocessing pass (signature detection, reply-trailer
stripping, structural classification) can hand the live fragment to
Markbridge with no serialize → re-parse round-trip in between:

```ruby
# Before — two Nokogiri parses per post
processed = MyImporter::SignatureWrapper.wrap(html)   # parse + mutate + to_html
result    = Markbridge.html_to_markdown(processed)    # parse again

# After — one Nokogiri parse per post
fragment = Nokogiri::HTML.fragment(html)
MyImporter::SignatureWrapper.wrap_dom!(fragment)      # in-place mutation
result   = Markbridge.html_to_markdown(fragment)
```

Same affordance on TextFormatter:

```ruby
xml_doc = Nokogiri.XML(input)
# … inspect / mutate xml_doc …
result = Markbridge.text_formatter_xml_to_markdown(xml_doc)
```

Documents are unwrapped via `#root`; any other `Nokogiri::XML::Node`
(Fragment, Element) is treated as the root directly. String callers
are unchanged — the `.to_s` fallback covers `Pathname`, `IO`, and
any other object that historically went through `.to_s` coercion.

The HTML round-trip avoidance also fixes a documented side effect:
re-serialization percent-encodes non-ASCII bytes in URL attributes.

### AST traversal helpers on `Element`

Three new methods replace the recursive-descent boilerplate every
consumer was rolling on its own:

```ruby
# Walk every descendant in depth-first pre-order.
result.ast.each_descendant { |node| ... }

# Filter by class (uses is_a? — abstract bases match subclasses).
mentions = result.ast.descendants(MyAst::Mention)

# Swap a direct child in place, preserving index.
result.ast.replace_child(old_paragraph, new_details_block)
```

`each_descendant` snapshots the children array of each Element at
iteration entry, so mid-walk `replace_child` is safe — descent uses
the pre-replacement reference. Appends to the same array during the
walk are *not* re-visited (prevents unbounded recursion when a node
appends another node).

### `Markbridge::AST::Details` + `DetailsTag`

The collapsible Discourse `[details=…]…[/details]` block is now a
core AST node + auto-registered Tag. Importers can drop any local
`DetailsBlock` / `DetailsBlockTag` shim:

```ruby
ast << Markbridge::AST::Details.new(title: "Signature").tap do |block|
  block << Markbridge::AST::Text.new("--\nAlex Doe")
end
# Markdown:   \n\n[details="Signature"]\n--\nAlex Doe\n[/details]\n\n
# html_mode:  <details><summary>Signature</summary>…</details>
```

`title` is optional — omitting it produces a bare `[details]` (BBCode
parser default) and `<summary>Summary</summary>` in html_mode. The
title is HTML-escaped in the `<summary>` text.

### See also

- `examples/forum_migration.rb` — canonical end-to-end importer shape
  exercising every new path: `discourse_renderer` factory, `tags:`,
  `unregister:`, `allow: :lists`, the AST-mutation block,
  `raise_on_error: false`, `Markbridge.convert(format:)` dispatch,
  pre-parsed Nokogiri input, AST traversal helpers, `AST::Details`.
- `docs/extending.md` — how to add custom tags and handlers.
