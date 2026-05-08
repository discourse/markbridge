---
title: Placeholders
description: Render links, uploads, mentions, and other importer-resolved tags as placeholder strings, with side data emitted alongside the Markdown.
---

A *placeholder* is a short literal string in the rendered Markdown that the Discourse importer swaps for a real value later: an upload reference, a topic link, a resolved mention. Markbridge gives you everything you need to produce that placeholder *and* record the resolution data alongside it, in one render pass.

The pattern looks like this:

<figure class="diagram">
  <img class="diagram-light" src="/diagrams/placeholders.svg" alt="Placeholder triad: source [attachment=0] tag becomes AttachmentPlaceholder AST node, which the renderer Tag splits into a [attachment|0] string in the Markdown output and an emissions record on Conversion#emissions">
  <img class="diagram-dark" src="/diagrams/placeholders-dark.svg" alt="Placeholder triad: source [attachment=0] tag becomes AttachmentPlaceholder AST node, which the renderer Tag splits into a [attachment|0] string in the Markdown output and an emissions record on Conversion#emissions">
</figure>

Every placeholder concept follows the same triad: an **AST node** to carry the parsed data, a **parser handler** to construct it, and a **renderer Tag** to format the placeholder and emit the side data.

> Markbridge ships with a built-in `Markbridge::AST::Attachment` that maps to Discourse's resolved upload syntax. For migrations the source post doesn't *have* a Discourse upload yet — it has a reference to a row in the source forum's attachments table. Define your own AST class so the importer can resolve those references after the rendering pass.

## The placeholder triad, end to end

Worked example for **phpBB3**, which emits attachments as `[attachment=N]filename[/attachment]` where `N` is the **position index** of the attachment within the post (zero-based). The actual file lives in `phpbb_attachments` joined to the post; the BBCode just points at slot N.

The pipeline below turns `[attachment=0]filename.jpg[/attachment]` into `[attachment|0]` in the output, with `{position: 0, filename: "filename.jpg"}` recorded on `result.emitted(:attachments)` so the importer can swap the placeholder for a real Discourse upload reference once it has resolved the source row.

(vBulletin's `[ATTACH]N[/ATTACH]` and IPB's `[attachment=N:filename]` follow the same shape — the example below adapts to either by tweaking the handler.)

### 1. The AST node

```ruby
module ForumMigration
  class AttachmentPlaceholder < Markbridge::AST::Element
    attr_reader :position

    def initialize(position:)
      super()
      @position = position
    end
  end
end
```

`Element` lets it accept children (the filename text). `attr_reader` keeps it immutable. Pick whatever class name maps to your domain — `ForumMigration::AttachmentPlaceholder`, `Migration::SourceAttachment`, anything that won't collide with built-in AST classes.

### 2. The parser handler

```ruby
module ForumMigration
  class AttachmentHandler < Markbridge::Parsers::BBCode::Handlers::BaseHandler
    def initialize
      @element_class = AttachmentPlaceholder
    end

    attr_reader :element_class

    def on_open(token:, context:, registry:, tokens: nil)
      position = Integer(token.attrs[:option] || token.attrs[:id])
      context.push(AttachmentPlaceholder.new(position:))
    end
  end
end
```

The handler reads `[attachment=0]`'s attribute and constructs the AST node. The default `on_close` from `BaseHandler` handles `[/attachment]`. Markbridge ships a handler for `[attachment]` / `[attach]` already (it builds `AST::Attachment`); registering this one overrides the defaults so they go through your migration-aware path.

### 3. The renderer Tag

```ruby
class AttachmentPlaceholderTag < Markbridge::Renderers::Discourse::Tag
  def render(element, interface)
    filename = interface.render_children(element)
    interface.emit(:attachments, position: element.position, filename:)
    "[attachment|#{element.position}]"
  end
end
```

Three lines doing the meaningful work: collect any nested content, emit the side data the importer needs, return the placeholder string.

### 4. Wire it up

```ruby
HANDLERS =
  Markbridge::Parsers::BBCode::HandlerRegistry.default.tap do |r|
    r.register(%w[attachment attach], ForumMigration::AttachmentHandler.new)
  end

RENDERER =
  Markbridge.discourse_renderer(
    tags: { ForumMigration::AttachmentPlaceholder => AttachmentPlaceholderTag.new },
  )
```

A single `.new` is registered under both `[attachment]` and `[attach]` so the closing strategy finds the same handler instance on both sides — see [Extending Markbridge → Wrapping a default handler](/customization/extending/#wrapping-a-default-handler) for why this matters when one handler covers multiple aliases.

### 5. Use it

```ruby
result = Markbridge.bbcode_to_markdown(
  "Screenshot: [attachment=0]screenshot.png[/attachment] — see what I mean?",
  handlers: HANDLERS,
  renderer: RENDERER,
)

result.markdown
# => "Screenshot: [attachment|0] — see what I mean?"

result.emitted(:attachments)
# => [{position: 0, filename: "screenshot.png"}]
```

The importer's job from here: pull the source post's attachment rows (ordered by their natural ID), match each by position to the emitted records, store the new uploads, and substitute `[attachment|N]` placeholders for resolved Discourse upload references in the post body.

## Placeholder strings pass through verbatim

A common worry: "if my placeholder contains `[`, won't the Markdown escaper mangle it?" It will not.

Markbridge escapes only `AST::Text` nodes — the textual content from the source document. A Tag's return value is spliced into its parent's output with no transformation. Whatever you return from `Tag#render` is exactly what appears in the surrounding Markdown.

This is what makes placeholders safe. `"[attachment|0]"`, `"@@MENTION:alice@@"`, `"<<TOPIC:7>>"` all reach the output untouched. Pick whatever sigil pattern your importer parses cleanly downstream.

The one twist is HTML mode (next section).

## HTML mode and placeholders

When a parent renders an HTML block — currently only `TableTag` doing its HTML-fallback path for uneven rows or nested tables — children render with `interface.html_mode?` true. Per [CommonMark §4.6](https://spec.commonmark.org/0.31.2/#html-blocks), content inside an HTML block is treated as raw HTML, not Markdown, until the next blank line. Your placeholder Tag has two valid choices:

**Raw HTML.** If your placeholder has a natural HTML form, emit it directly:

```ruby
class AttachmentPlaceholderTag < Markbridge::Renderers::Discourse::Tag
  def render(element, interface)
    interface.emit(:attachments, position: element.position)

    if interface.html_mode?
      %(<a href="attachment://#{element.position}">attachment</a>)
    else
      "[attachment|#{element.position}]"
    end
  end
end
```

**Markdown island.** If your placeholder is an opaque sigil that downstream tooling parses regardless of context, wrap it in blank lines so CommonMark closes the HTML block, parses your placeholder as Markdown, and re-opens it:

```ruby
"\n\n[attachment|#{element.position}]\n\n"
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
