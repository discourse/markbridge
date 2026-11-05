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

Markbridge escapes only `AST::Text` nodes — the textual content from the source document. A Tag's return value is written into its parent's output as it is. Whatever you return from `Tag#render` is exactly what appears in the surrounding Markdown.

This is what makes placeholders safe. `"[upload|u_screenshot_png_3a7c2]"`, `"@@MENTION:alice@@"`, `"<<TOPIC:7>>"` all reach the output untouched. Pick whatever sigil pattern your importer parses cleanly downstream.

What the renderer can add is something *between* a placeholder and its neighbor: a backslash in front of a `!`, or an empty HTML comment (`<!---->`) next to emphasis markers or a mention. It decides that from the characters on both sides of the join, and for a String placeholder those are the placeholder's own characters. The next section shows how to tell it what will stand there instead.

## Tell Markbridge what replaces the placeholder

Whether `**` opens or closes, whether `@alice` is a mention and whether a bare URL is linked depends on the characters right next to it. The renderer knows these rules and puts an invisible `<!---->` where a join needs one. With a String placeholder it sees the placeholder, not the text the importer puts there later:

| The renderer writes | The importer replaces `[link\|17]` | Cooked by Discourse |
|---|---|---|
| `**See:**[link\|17]` | `**See:**https://forum.example.com/t/17` | the `**` stay visible: a closing `**` after `:` and in front of a letter doesn't close |
| `**See:**<!---->[link\|17]` | `**See:**<!---->https://forum.example.com/t/17` | **See:** and the link |

`]` is punctuation, and a closing `**` in front of punctuation closes, so the renderer sees no reason for the comment. The URL that comes later starts with a letter.

### Inline placeholders: `Tokens.placeholder`

A tag for a placeholder that ends up inline (a link, a mention, an inline image) returns a placeholder token instead of a String. It names the placeholder text and what will most likely replace it:

```ruby
Tokens = Markbridge::Renderers::Discourse::Inline::Tokens

class TopicLinkTag < Markbridge::Renderers::Discourse::Tag
  def initialize(topics:)
    @topics = topics # source URL => Discourse topic id
  end

  def render(element, _interface)
    topic_id = @topics.fetch(element.href)
    [Tokens.placeholder("[link|#{topic_id}]", like: "https://forum.example.com/t/#{topic_id}")]
  end
end

topics = { "http://old.example.com/viewtopic.php?t=17" => 17 }
renderer = Markbridge.discourse_renderer(tags: { Markbridge::AST::Url => TopicLinkTag.new(topics:) })

Markbridge.bbcode_to_markdown(
  "[b]See:[/b][url]http://old.example.com/viewtopic.php?t=17[/url]",
  renderer:,
).markdown
# => "**See:**<!---->[link|17]"
```

The tag returns an Array with one token, like the built-in link tags do (see [Tags that return inline tokens](/customization/extending/#tags-that-return-inline-tokens)). The renderer writes `[link|17]` exactly as it is, but it joins it with the text around it as if `https://forum.example.com/t/17` stood there. The importer replaces `[link|17]` and gets Markdown in which every join is right.

What `like:` changes, with `[link|17]` standing for a URL and `[mention|3]` for `@alice`:

| Next to the placeholder | Without `like:` | With `like:` | Why |
|---|---|---|---|
| a closing marker in front: `**See:**` | `**See:**[link\|17]` | `**See:**<!---->[link\|17]` | a closing `**` after punctuation must not have a letter after it |
| an opening marker after it: `*.txt*` | `[link\|17]*.txt*` | `[link\|17]<!---->*.txt*` | an opening `*` with punctuation after it must not have a letter in front |
| a word in front of a mention: `Thanks` | `Thanks[mention\|3]!` | `Thanks<!---->[mention\|3]!` | Discourse renders `@alice` as a mention only when a space or punctuation stands in front of it in the same text; `Thanks@alice` is no mention, the comment starts a new text |
| a `!` in front: `Look!` | `Look\![link\|17]` | `Look![link\|17]` | the backslash is for `![`, which starts an image; the URL doesn't start with `[` |
| a bare URL in front | depends on `[` | depends on the first character of `like:` | text glued to a bare URL turns it into `[url](url)` |
| a bare URL after it | depends on `]` | depends on the last character of `like:` | the same, the other way |

<!-- spec:continue -->
```ruby
Markbridge.bbcode_to_markdown(
  "[url]http://old.example.com/viewtopic.php?t=17[/url][i].txt[/i] and Look![url]http://old.example.com/viewtopic.php?t=17[/url]",
  renderer:,
).markdown
# => "[link|17]<!---->*.txt* and Look![link|17]"
```

The comment is invisible in the cooked post, and it is only there where the join needs it: `See: [link|17]` with a space gets none.

### Choosing `like:`

Only the first and the last character of `like:` decide anything, so it doesn't have to be the real value. It has to start and end the way the replacement will:

| The importer writes | Pass as `like:` | First and last character |
|---|---|---|
| a URL, bare (an internal link, a onebox) | `"https://forum.example.com/t/17"` | a letter, a letter or digit |
| a URL that ends with `/` | `"https://forum.example.com/"` | a letter, punctuation |
| a link with text | `"[text](https://forum.example.com/t/17)"` | `[`, `)` |
| a mention | `"@alice"` | `@`, a letter |
| an image upload | `"![photo\|690x460](upload://a.png)"` | `!`, `)` |
| an attachment | `"[report.pdf\|attachment](upload://b.pdf)"` | `[`, `)` |
| an emoji | `":smile:"` | `:`, `:` |

When the replacement can take more than one form, use the one the importer writes most often. When the importer knows the value already at render time (the username of a mention, the URL of a topic), pass the value itself. `like:` must be a non-empty String; a Symbol or `nil` raises an `ArgumentError`.

### Pick a placeholder with punctuation at both ends

`like:` decides the joins of the placeholder with its neighbors. Inside emphasis or a link label, the renderer also checks the edges of the content, for example whether `**` can open in front of it, and there the content is finished text already: it reads the placeholder's own characters. A placeholder that starts and ends with punctuation gives the safe answer there, at worst an extra `<!---->` that changes nothing:

<!-- spec:continue -->
```ruby
serializer = Markbridge::Renderers::Discourse::Inline::Serializer.new(
  escaper: Markbridge::Renderers::Discourse::MarkdownEscaper.new,
)
bold = ->(*content) { [Tokens.open(:strong), *content, Tokens.close(:strong)] }

serializer.write([Tokens.text("x"), *bold.(Tokens.placeholder("[mention|3]", like: "@alice"))])
# => "x<!---->**[mention|3]**"
serializer.write([Tokens.text("x"), *bold.(Tokens.placeholder("MENTION3", like: "@alice"))])
# => "x**MENTION3**"
```

The second one breaks once the importer puts `@alice` there: `x**@alice**` doesn't open. So use brackets or other punctuation at both ends (`[link|17]`, `[mention|3]`, `<<upload:9>>`), and keep the placeholder on one line, without blank lines and without `*`, `_`, `~` or `` ` `` at its edges.

### Block placeholders: polls, events and anything on its own line

A poll or an event ends up as a block of its own, so nothing stands next to it on its line and `like:` has nothing to decide. What matters is that the renderer treats it as a block:

- The tag returns the placeholder with a blank line on both sides, like the built-in `PollTag` and `EventTag` do: `"\n\n[poll|3]\n\n"`. Inside a quote or a list item, the quote and the list item tags put `> ` in front of it or indent it like any block.
- The normalizer moves blocks out of bold, italic, links and headings before the renderer runs. It decides that by the AST class: `AST::Poll` and `AST::Event` are blocks. For your own AST class, tell it:

<!-- spec:before
Tokens = Markbridge::Renderers::Discourse::Inline::Tokens
-->
```ruby
module ForumMigration
  class PollPlaceholder < Markbridge::AST::Node
    attr_reader :poll_id

    def initialize(poll_id:)
      @poll_id = poll_id
    end
  end

  class PollPlaceholderTag < Markbridge::Renderers::Discourse::Tag
    def render(element, _interface)
      "\n\n[poll|#{element.poll_id}]\n\n"
    end
  end
end

renderer =
  Markbridge.discourse_renderer(
    tags: { ForumMigration::PollPlaceholder => ForumMigration::PollPlaceholderTag.new },
  )

# A poll inside bold, as a forum post can have it.
document = Markbridge::AST::Document.new
bold = Markbridge::AST::Bold.new
bold << Markbridge::AST::Text.new("Vote:") << ForumMigration::PollPlaceholder.new(poll_id: 3)
document << bold

Markbridge.render(document, renderer:).markdown
# => "**Vote:**\n\n**[poll|3]**"

# Tell the normalizer that the placeholder is a block.
normalizer = Markbridge::Normalizer.default
Markbridge::Normalizer::INLINE_CONTAINERS.each do |container|
  normalizer.rule(parent: container, child: ForumMigration::PollPlaceholder, strategy: :hoist_after)
end

Markbridge.render(document, renderer:, normalize: normalizer).markdown
# => "**Vote:**\n\n[poll|3]"
```

Without the rule the placeholder stays inside the bold. Its blank lines split the bold into paragraphs, and every paragraph gets its own markers, so the importer would find `**[poll|3]**`. Pass the same normalizer to every conversion (`normalize:` works on `bbcode_to_markdown` and the other `*_to_markdown` methods too). The same applies to an upload or a link that the importer turns into a block, for example a onebox on its own line: return the block form from the tag and add the rules for its AST class.

### Checklist for a new converter

For every kind of placeholder, whether you write the converter yourself or a coding agent does:

1. **Inline or block?** Decide from what the importer puts there, not from the source tag.
2. **Inline:** return `[Tokens.placeholder(text, like:)]` from the tag. Set `like:` to what the importer will most likely write, or to something that starts and ends with the same kind of character (see the table above).
3. **Block:** return `"\n\n#{text}\n\n"` from the tag, and make sure the normalizer knows the AST class is a block: a built-in block class, or the rules above.
4. **The placeholder text:** punctuation at both ends, one line, no blank lines, and unique enough that the importer finds every one and nothing else.
5. **html_mode:** decide what the placeholder becomes inside an HTML table, see [HTML mode and placeholders](#html-mode-and-placeholders). A placeholder token is written as it is there.
6. **Check it:** convert a few real posts, replace every placeholder with its `like:` value, cook the result and look at it next to the source post. Replacing is all the importer does later, so what you see is what the forum will show.

<!-- spec:continue -->
```ruby
markdown = Markbridge.bbcode_to_markdown(
  "[b]See:[/b][url]http://old.example.com/viewtopic.php?t=17[/url]",
  renderer: Markbridge.discourse_renderer(tags: { Markbridge::AST::Url => TopicLinkTag.new(topics:) }),
).markdown

markdown.gsub("[link|17]", "https://forum.example.com/t/17")
# => "**See:**<!---->https://forum.example.com/t/17"
```

That's the Markdown the importer hands to Discourse.

## HTML mode and placeholders

When a parent renders an HTML block — currently only `TableTag` doing its HTML-fallback path for uneven rows or nested tables — children render with `interface.html_mode?` true. Per [CommonMark §4.6](https://spec.commonmark.org/0.31.2/#html-blocks), content inside an HTML block is treated as raw HTML, not Markdown, until the next blank line. Your placeholder Tag has two valid choices:

A placeholder token (`Tokens.placeholder`) is written as it is in html_mode too, so these choices apply to it as well.

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

- [Customizing the renderer](/customization/customizing-renderer/) — the factory kwargs in detail.
- [Extending Markbridge](/customization/extending/) — broader extension patterns including `HandlerRegistry#overlay` for delegating to default handlers.
