---
title: Placeholders
description: Render links, uploads, mentions, and other importer-resolved tags as placeholder strings, with side data emitted alongside the Markdown.
---

A *placeholder* is a short literal string in the rendered Markdown that the Discourse importer swaps for a real value later: an upload reference, a topic link, a resolved mention. Markbridge gives you everything you need to produce that placeholder *and* record the resolution data alongside it, in one render pass.

The pattern looks like this:

<figure class="diagram">
  <img class="diagram-light" src="/diagrams/placeholders.svg" alt="Placeholder triad: source [upload=42] tag becomes UploadPlaceholder AST node, which the renderer Tag splits into a [upload|42] string in the Markdown output and an emissions record on Conversion#emissions">
  <img class="diagram-dark" src="/diagrams/placeholders-dark.svg" alt="Placeholder triad: source [upload=42] tag becomes UploadPlaceholder AST node, which the renderer Tag splits into a [upload|42] string in the Markdown output and an emissions record on Conversion#emissions">
</figure>

Every placeholder concept follows the same triad: an **AST node** to carry the parsed data, a **parser handler** to construct it, and a **renderer Tag** to format the placeholder and emit the side data.

> Markbridge ships with a built-in `Markbridge::AST::Upload` for *resolved* uploads (it carries a Discourse-side `sha1:`). For *placeholders*, define your own AST class — the source-forum upload ID isn't an upload yet, just a reference the importer will resolve.

## The placeholder triad, end to end

Concrete worked example: `[upload=42]filename.jpg[/upload]` becomes `[upload|42]` in the output, with `{source_id: 42, filename: "filename.jpg"}` recorded on `result.emitted(:uploads)`.

### 1. The AST node

```ruby
module ForumMigration
  class UploadPlaceholder < Markbridge::AST::Element
    attr_reader :source_id

    def initialize(source_id:)
      super()
      @source_id = source_id
    end
  end
end
```

`Element` lets it accept children (the filename text). `attr_reader` keeps it immutable. Pick whatever class name maps to your domain — `ForumMigration::UploadPlaceholder`, `Migration::SourceUpload`, anything that won't collide with built-in AST classes.

### 2. The parser handler

```ruby
module ForumMigration
  class UploadHandler < Markbridge::Parsers::BBCode::Handlers::BaseHandler
    def initialize
      @element_class = UploadPlaceholder
    end

    attr_reader :element_class

    def on_open(token:, context:, registry:, tokens: nil)
      source_id = Integer(token.attrs[:option] || token.attrs[:id])
      context.push(UploadPlaceholder.new(source_id:))
    end
  end
end
```

The handler reads `[upload=42]`'s attribute and constructs the AST node. The default `on_close` from `BaseHandler` handles `[/upload]`. If your source forum stores upload IDs differently (paths, slugs, hash references), this is where you translate — the rest of the pipeline just deals with the resolved AST node.

### 3. The renderer Tag

```ruby
class UploadPlaceholderTag < Markbridge::Renderers::Discourse::Tag
  def render(element, interface)
    filename = interface.render_children(element)
    interface.emit(:uploads, source_id: element.source_id, filename:)
    "[upload|#{element.source_id}]"
  end
end
```

Three lines doing the meaningful work: collect any nested content, emit the side data the importer needs, return the placeholder string.

### 4. Wire it up

```ruby
HANDLERS =
  Markbridge::Parsers::BBCode::HandlerRegistry.default.tap do |r|
    r.register(%w[upload attach attachment], ForumMigration::UploadHandler.new)
  end

RENDERER =
  Markbridge.discourse_renderer(tags: { ForumMigration::UploadPlaceholder => UploadPlaceholderTag.new })
```

### 5. Use it

```ruby
result = Markbridge.bbcode_to_markdown(
  "Here is [upload=42]photo.jpg[/upload], take a look.",
  handlers: HANDLERS,
  renderer: RENDERER,
)

result.markdown
# => "Here is [upload|42], take a look."

result.emitted(:uploads)
# => [{source_id: 42, filename: "photo.jpg"}]
```

The importer's job from here: walk `result.emitted(:uploads)`, store an upload row keyed by `source_id`, and trust that the placeholder `[upload|42]` will be substituted in the post body downstream.

## Placeholder strings pass through verbatim

A common worry: "if my placeholder contains `[`, won't the Markdown escaper mangle it?" It will not.

Markbridge escapes only `AST::Text` nodes — the textual content from the source document. A Tag's return value is spliced into its parent's output with no transformation. Whatever you return from `Tag#render` is exactly what appears in the surrounding Markdown.

This is what makes placeholders safe. `"[upload|42]"`, `"@@MENTION:alice@@"`, `"<<TOPIC:7>>"` all reach the output untouched. Pick whatever sigil pattern your importer parses cleanly downstream.

The one twist is HTML mode (next section).

## HTML mode and placeholders

When a parent renders an HTML block — currently only `TableTag` doing its HTML-fallback path for uneven rows or nested tables — children render with `interface.html_mode?` true. Per [CommonMark §4.6](https://spec.commonmark.org/0.31.2/#html-blocks), content inside an HTML block is treated as raw HTML, not Markdown, until the next blank line. Your placeholder Tag has two valid choices:

**Raw HTML.** If your placeholder has a natural HTML form, emit it directly:

```ruby
class UploadTag < Markbridge::Renderers::Discourse::Tag
  def render(element, interface)
    interface.emit(:uploads, id: element.upload_id)

    if interface.html_mode?
      %(<a href="upload://#{element.upload_id}">attachment</a>)
    else
      "[upload|#{element.upload_id}]"
    end
  end
end
```

**Markdown island.** If your placeholder is an opaque sigil that downstream tooling parses regardless of context, wrap it in blank lines so CommonMark closes the HTML block, parses your placeholder as Markdown, and re-opens it:

```ruby
"\n\n[upload|#{element.upload_id}]\n\n"
```

The blank lines force a paragraph break around the placeholder, which is fine for block-level placeholders (uploads in tables tend to want their own row anyway) but unsightly for inline ones (mentions, links). Prefer the raw-HTML form for inline placeholders that can land inside tables.

## More than one emission per Tag

A Tag can call `emit` more than once and across multiple keys per call:

```ruby
class InternalLinkTag < Markbridge::Renderers::Discourse::Tag
  def render(element, interface)
    interface.emit(:internal_links, source_topic_id: element.source_topic_id)

    unless RESOLVED_TOPICS.key?(element.source_topic_id)
      interface.emit(:unresolved_topics, source_id: element.source_topic_id)
    end

    "[topic|#{element.source_topic_id}]"
  end
end
```

The importer reads `result.emitted(:internal_links)` and `result.emitted(:unresolved_topics)` independently. Emissions don't have to be balanced or paired — emit whatever shape your downstream code consumes.

## Resolution: handler vs Tag

Where should the source-id-to-Discourse-id resolution happen — in the handler (parse time) or the Tag (render time)?

| Resolution at parse | Resolution at render |
|---|---|
| Handler does the lookup; AST node carries the resolved Discourse value. | Handler stores the source value; Tag does the lookup at render. |
| Failures surface as missing AST nodes (or `unknown_tags` bumps). | Failures surface as emissions you reconcile after. |
| Cleaner separation; the renderer is dumb. | Lets you batch lookups across many calls or defer entirely. |

The forum-migration tradeoff usually goes: simple lookups (path → slug, name → user_id) at parse time; lookups that require global state (cross-post topic IDs) at render time, with Tags emitting unresolved references for a second-pass resolution. There's no one right answer — pick the side that matches your data flow.

## What goes in the AST node

A few rules of thumb for the placeholder AST node:

- Carry only what the renderer Tag needs. If the importer needs more (timestamps, original URLs, hash-of-original), put it on the emission payload, not the AST node.
- Use `attr_reader` and a keyword constructor. Mutability has no upside here.
- Inherit from `Element` if it can wrap inline content (link text, mention name). Inherit from `Node` if it's a leaf (a poll, an event, a hr-style separator).
- One AST class per *concept*, not per *source tag alias*. `[url]`, `[link]`, and `[iurl]` all build `AST::Url`; the same Tag renders all three. The same applies to placeholders that have multiple aliases in the source format.

## Where next

- [Full walkthrough](/migrating/full-walkthrough/) — a runnable mini-importer that exercises this triad alongside handler delegation, custom escaper, and `Markbridge.convert(format:)` dispatch.
- [Customizing the renderer](/customization/customizing-renderer/) — the factory kwargs in detail.
- [Extending Markbridge](/customization/extending/) — broader extension patterns including `HandlerRegistry#overlay` for delegating to default handlers.
