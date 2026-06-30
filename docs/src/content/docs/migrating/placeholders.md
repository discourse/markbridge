---
title: Placeholders
description: Render links, uploads, mentions, and other importer-resolved tags as placeholder strings, then collect what you need by walking the parsed AST.
---

A *placeholder* is a short literal string in the rendered Markdown that the Discourse importer swaps for a real value later: an upload reference, a topic link, a resolved mention. Markbridge gives you everything you need to produce that placeholder, and to find every placeholder again afterwards by walking the parsed tree — no side channel required.

The pattern looks like this:

<figure class="diagram">
  <img class="diagram-light" src="/diagrams/placeholders.svg" alt="The placeholder flow: a source [attachment=0] tag becomes an AttachmentPlaceholder AST node, which the renderer Tag formats into a [upload|HASH] string in the Markdown output; the importer re-reads the same nodes via conversion.ast.descendants">
  <img class="diagram-dark" src="/diagrams/placeholders-dark.svg" alt="The placeholder flow: a source [attachment=0] tag becomes an AttachmentPlaceholder AST node, which the renderer Tag formats into a [upload|HASH] string in the Markdown output; the importer re-reads the same nodes via conversion.ast.descendants">
</figure>

Every placeholder is built from the same three parts: an **AST node** to hold the parsed data, a **parser handler** to build that node, and a **renderer Tag** to turn it into the placeholder string. When the importer later needs the details (which uploads a post used, which mentions to look up), it reads them back off the AST nodes — `conversion.ast` is the same tree that produced the Markdown, so `conversion.ast.descendants(YourPlaceholder)` hands you every placeholder that made it through parsing.

> Markbridge ships with a built-in `Markbridge::AST::Attachment` that maps to Discourse's resolved upload syntax. For migrations the source post doesn't *have* a Discourse upload yet — it has a reference to a row in the source forum's attachments table. Define your own AST class so the importer can resolve those references.

## The three parts, end to end

Concrete example: phpBB3 emits attachments as `[attachment=N]filename[/attachment]`, where `N` is the position index of the attachment within the post (zero-based). The actual file lives in `phpbb_attachments` joined to the post; the BBCode just points at slot N.

The pipeline below turns `[attachment=0]filename.jpg[/attachment]` into `[upload|<upload_id>]` in the output — Discourse's upload-marker shape, with the upload identifier looked up from the source post's attachment rows. The `upload_id` is whatever stable identifier the importer's converter framework derives from the source filename/path (not the file's content hash) so each placeholder maps unambiguously to one source-side row.

(vBulletin's `[ATTACH]N[/ATTACH]` and IPB's `[attachment=N:filename]` follow the same shape — the example below adapts to either by tweaking the handler.)

### 1. The AST node

```ruby
module ForumMigration
  class AttachmentPlaceholder < Markbridge::AST::Node
    attr_reader :position, :filename

    def initialize(position:, filename: nil)
      @position = position
      @filename = filename
    end
  end
end
```

`Node` (rather than `Element`) makes it a leaf — the filename comes from the BBCode body but the handler captures it at parse time and pins it on the node, so there are no children to render. Pick whatever class name maps to your domain — `ForumMigration::AttachmentPlaceholder`, `Migration::SourceAttachment`, anything that won't collide with built-in AST classes.

### 2. The parser handler

<!-- spec:continue -->
```ruby
module ForumMigration
  class AttachmentHandler < Markbridge::Parsers::BBCode::Handlers::BaseHandler
    def initialize
      @element_class = AttachmentPlaceholder
      @collector = Markbridge::Parsers::BBCode::RawContentCollector.new
    end

    attr_reader :element_class

    def on_open(token:, context:, registry:, tokens: nil)
      position = Integer(token.attrs[:option] || token.attrs[:id])
      filename = tokens && @collector.collect(token.tag, tokens).content
      context.add_child(AttachmentPlaceholder.new(position:, filename: presence(filename)))
    end

    # The collector consumes the closing tag; if one slips through, render it as literal text.
    def on_close(token:, context:, registry:, tokens: nil)
      context.add_child(Markbridge::AST::Text.new(token.source))
    end

    private

    def presence(string)
      stripped = string&.strip
      stripped unless stripped.nil? || stripped.empty?
    end
  end
end
```

`RawContentCollector` is the same helper Markbridge's built-in `AttachmentHandler` uses to grab the body between `[attachment=0]` and `[/attachment]` as a literal string. Storing the filename on the node directly means the renderer Tag doesn't have to call `render_children` later. Markbridge ships a handler for `[attachment]` / `[attach]` already (it builds `AST::Attachment`); registering this one overrides the defaults so they go through your migration-aware path.

### 3. The renderer Tag

The Tag needs the post's attachment list at render time so it can map a position to an `upload_id`. Pass it through the constructor. The Tag stays a one-line output formatter — no side effects, just a string:

<!-- spec:continue -->
```ruby
module ForumMigration
  class AttachmentPlaceholderTag < Markbridge::Renderers::Discourse::Tag
    def initialize(attachments:)
      @attachments = attachments # ordered list, indexed by position
    end

    def render(element, _interface)
      attachment = @attachments[element.position]
      "[upload|#{attachment.upload_id}]"
    end
  end
end
```

`[upload|<id>]` is the upload-marker shape Discourse importers recognize — they substitute a real `upload://...` URL once the file has been ingested.

### 4. Wire it up

The handler is stateless, so register it once and share it across every post. The renderer holds the per-post attachment list, so build it inside the migration loop:

<!-- spec:before
module SourceDB
  Attachment = Struct.new(:upload_id, :filename, keyword_init: true)
  def self.attachments_for(_post_id)
    [Attachment.new(upload_id: "u_screenshot_png_3a7c2", filename: "screenshot.png")]
  end
end
Post = Struct.new(:id, :body, keyword_init: true)
posts = [Post.new(id: 1, body: "see [attachment=0]screenshot.png[/attachment]")]
def store(_post, _markdown, _attachments); end
-->
<!-- spec:continue -->
```ruby
handlers =
  Markbridge::Parsers::BBCode::HandlerRegistry.default.tap do |r|
    r.register(%w[attachment attach], ForumMigration::AttachmentHandler.new)
  end

posts.each do |post|
  attachments = SourceDB.attachments_for(post.id) # ordered by attach_id
  renderer =
    Markbridge.discourse_renderer(
      tags: {
        ForumMigration::AttachmentPlaceholder =>
          ForumMigration::AttachmentPlaceholderTag.new(attachments:),
      },
    )

  result = Markbridge.bbcode_to_markdown(post.body, handlers:, renderer:)

  # The placeholders that made it into the output are exactly the
  # AttachmentPlaceholder nodes left in the tree. Walk them to record
  # which uploads this post referenced.
  referenced = result.ast.descendants(ForumMigration::AttachmentPlaceholder)
  store(post, result.markdown, referenced)
end
```

One handler instance is registered under both `[attachment]` and `[attach]`, so the closing logic finds the same object on both sides. When a tag has several names like this, you have to share one instance — [Extending Markbridge](/customization/extending/#wrapping-a-default-handler) explains why.

Constructing the renderer per post breaks the build-once-reuse-many pattern, but only for the slice of state that varies post-to-post (the attachment table). Shared parts — handler registry, custom escaper, postprocessor, decorators that don't depend on per-post data — stay outside the loop.

### 5. What you get

<!-- spec:before
module SourceDB
  Attachment = Struct.new(:upload_id, :filename, keyword_init: true)
end
-->
<!-- spec:continue -->
```ruby
attachments = [SourceDB::Attachment.new(upload_id: "u_screenshot_png_3a7c2", filename: "screenshot.png")]
renderer = Markbridge.discourse_renderer(
  tags: {
    ForumMigration::AttachmentPlaceholder =>
      ForumMigration::AttachmentPlaceholderTag.new(attachments:),
  },
)
handlers = Markbridge::Parsers::BBCode::HandlerRegistry.default.tap do |r|
  r.register(%w[attachment attach], ForumMigration::AttachmentHandler.new)
end

result = Markbridge.bbcode_to_markdown(
  "Screenshot: [attachment=0]screenshot.png[/attachment] — see what I mean?",
  handlers:,
  renderer:,
)

result.markdown
# => "Screenshot: [upload|u_screenshot_png_3a7c2] — see what I mean?"

# Re-read the placeholder nodes straight off the tree.
result.ast.descendants(ForumMigration::AttachmentPlaceholder).map(&:position)
# => [0]
```

The importer downstream substitutes `[upload|u_screenshot_png_3a7c2]` for the resolved `upload://...` URL once the file is ingested into Discourse's upload store.

## Placeholder strings pass through verbatim

A common worry: "if my placeholder contains `[`, won't the Markdown escaper mangle it?" It will not.

Markbridge escapes only `AST::Text` nodes — the textual content from the source document. A Tag's return value is spliced into its parent's output with no transformation. Whatever you return from `Tag#render` is exactly what appears in the surrounding Markdown.

This is what makes placeholders safe. `"[upload|u_screenshot_png_3a7c2]"`, `"@@MENTION:alice@@"`, `"<<TOPIC:7>>"` all reach the output untouched. Pick whatever sigil pattern your importer parses cleanly downstream.

The one twist is HTML mode (next section).

## HTML mode and placeholders

When a parent renders an HTML block — currently only `TableTag` doing its HTML-fallback path for uneven rows or nested tables — children render with `interface.html_mode?` true. Per [CommonMark §4.6](https://spec.commonmark.org/0.31.2/#html-blocks), content inside an HTML block is treated as raw HTML, not Markdown, until the next blank line. Your placeholder Tag has two valid choices:

**Raw HTML.** If your placeholder has a natural HTML form, emit it directly:

<!-- spec:continue -->
```ruby
module ForumMigration
  class AttachmentPlaceholderTag < Markbridge::Renderers::Discourse::Tag
    def render(element, interface)
      attachment = @attachments[element.position]

      if interface.html_mode?
        %(<a href="upload://#{attachment.upload_id}">attachment</a>)
      else
        "[upload|#{attachment.upload_id}]"
      end
    end
  end
end
```

**Markdown island.** If your placeholder is an opaque sigil that downstream tooling parses regardless of context, wrap it in blank lines so CommonMark closes the HTML block, parses your placeholder as Markdown, and re-opens it:

```ruby
upload_id = "u_screenshot_png_3a7c2"
"\n\n[upload|#{upload_id}]\n\n"
```

The blank lines force a paragraph break around the placeholder, which is fine for block-level placeholders (uploads in tables tend to want their own row anyway) but unsightly for inline ones (mentions, links). Prefer the raw-HTML form for inline placeholders that can land inside tables.

## Collecting more than one kind of placeholder

A migration usually has several placeholder concepts in flight at once — uploads, internal links, mentions. Each gets its own AST class, and the importer pulls each kind off the tree independently after the conversion:

<!-- spec:before
module ForumMigration
  class InternalLink < Markbridge::AST::Element
    attr_reader :source_topic_id
    def initialize(source_topic_id:); super(); @source_topic_id = source_topic_id; end
  end
  class Mention < Markbridge::AST::Node
    attr_reader :username
    def initialize(username:); @username = username; end
  end
end
result = Markbridge.render(
  Markbridge::AST::Document.new.tap do |d|
    d << ForumMigration::InternalLink.new(source_topic_id: 42)
    d << ForumMigration::Mention.new(username: "alice")
  end,
)
RESOLVED_TOPICS = { 42 => 7 }.freeze
-->
```ruby
links    = result.ast.descendants(ForumMigration::InternalLink)
mentions = result.ast.descendants(ForumMigration::Mention)

# Reconcile whatever you need — e.g. flag links whose source topic
# didn't resolve to a Discourse topic yet.
unresolved = links.reject { |link| RESOLVED_TOPICS.key?(link.source_topic_id) }
```

Because the tree is the record, you never have to keep the collected data balanced or paired the way a side-channel buffer would force you to — each query is independent and reads exactly the nodes that reached the output.

## Resolution: handler vs Tag

Where should the source-id-to-Discourse-id resolution happen — in the handler (parse time) or the Tag (render time)?

| Resolution at parse | Resolution at render |
|---|---|
| Handler does the lookup; AST node carries the resolved Discourse value. | Handler stores the source value; Tag does the lookup at render. |
| Failures surface as missing AST nodes (or `unknown_tags` bumps). | Failures surface when you walk the tree afterwards and reconcile. |
| Cleaner separation; the renderer is dumb. | Lets you batch lookups across many calls or defer entirely. |

The forum-migration tradeoff usually goes: simple lookups (path → slug, name → user_id) at parse time; lookups that require global state (cross-post topic IDs) at render time, with a second pass over `conversion.ast.descendants(...)` to reconcile the references that need it. There's no one right answer — pick the side that matches your data flow.

## What goes in the AST node

A few rules of thumb for the placeholder AST node:

- Carry everything the importer needs to reconcile the placeholder later (position, original URL, source id, filename). The node *is* the record you read back via `descendants`, so don't drop data you'll want downstream.
- Use `attr_reader` and a keyword constructor. Mutability has no upside here.
- Inherit from `Element` if it can wrap inline content (link text, mention name). Inherit from `Node` if it's a leaf (a poll, an event, a hr-style separator).
- One AST class per *concept*, not per *source tag alias*. `[url]`, `[link]`, and `[iurl]` all build `AST::Url`; the same Tag renders all three. The same applies to placeholders that have multiple aliases in the source format.

## Where next

- [Full example](/migrating/full-walkthrough/) — a small importer you can run, putting these three parts to work next to handler wrapping, a custom escaper, and `Markbridge.convert(format:)`.
- [Customizing the renderer](/customization/customizing-renderer/) — the factory kwargs in detail.
- [Extending Markbridge](/customization/extending/) — broader extension patterns including `HandlerRegistry#overlay` for delegating to default handlers.
