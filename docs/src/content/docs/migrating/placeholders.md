---
title: Placeholders
description: Write links, uploads and mentions that your importer resolves later as placeholders, and find them again in the AST.
---

When a post is converted, some of what it points to does not exist in Discourse yet: the attachment is not uploaded, the linked topic is not imported, the user has no new name. You cannot write the final Markdown for these at that moment.

A placeholder solves that. It is a short text in the Markdown, like `[upload|42]`, that your importer replaces with the real value later. Markbridge writes the placeholder for you and keeps the data that belongs to it in the AST, where the importer finds it again:

<figure class="diagram">
  <img class="diagram-light" src="/diagrams/placeholders.svg" alt="The placeholder flow: a source [attachment=0] tag becomes an AttachmentPlaceholder AST node, which the renderer Tag formats into a [upload|HASH] string in the Markdown output; the importer re-reads the same nodes via conversion.ast.descendants">
  <img class="diagram-dark" src="/diagrams/placeholders-dark.svg" alt="The placeholder flow: a source [attachment=0] tag becomes an AttachmentPlaceholder AST node, which the renderer Tag formats into a [upload|HASH] string in the Markdown output; the importer re-reads the same nodes via conversion.ast.descendants">
</figure>

A placeholder has three parts:

- an **AST node** that holds the data from the source,
- a **parser handler** that builds the node,
- a **renderer tag** that writes the node as the placeholder text.

When the importer needs the details later (which uploads a post has, which users it mentions), it asks the tree: `conversion.ast.descendants(YourPlaceholder)` returns every node of your class in the post.

Markbridge has a built-in `AST::Attachment`, which is written as Discourse's upload Markdown. That is for an upload that exists. In a migration the post only has a reference to a row in the attachments table of the old forum, so you need a node of your own.

## An example from start to end

phpBB 3 writes an attachment as `[attachment=N]filename[/attachment]`. `N` is the position of the attachment in the post, starting at 0. The file itself is a row in `phpbb_attachments` that belongs to the post.

The code below turns `[attachment=0]filename.jpg[/attachment]` into `[upload|<upload_id>]`. The `upload_id` is the id your importer uses for that file. It has to be the same every time the importer runs and must name exactly one row of the source.

vBulletin (`[ATTACH]N[/ATTACH]`) and IPB (`[attachment=N:filename]`) work the same way, with small changes to the handler.

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

The class is a `Node`, not an `Element`, so it has no children. The file name stands between the tags in the BBCode, but the handler reads it and puts it on the node, and nothing is left to render. Name the class as you like and keep it in your own module, so it cannot clash with a built-in AST class.

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

    # The collector reads up to the closing tag. A closing tag without an opening one is text.
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

`RawContentCollector` reads everything between `[attachment=0]` and `[/attachment]` as text, without parsing it. The built-in `AttachmentHandler` uses it too. Markbridge already has a handler for `[attachment]` and `[attach]`, which builds an `AST::Attachment`. Registering yours for the same names replaces it.

### 3. The renderer Tag

The tag has to turn a position into an `upload_id`, and for that it needs the attachments of the post. Pass them to its constructor:

<!-- spec:continue -->
```ruby
module ForumMigration
  class AttachmentPlaceholderTag < Markbridge::Renderers::Discourse::Tag
    def initialize(attachments:)
      @attachments = attachments # ordered list, indexed by position
    end

    def render(element, interface)
      attachment = @attachments[element.position]
      interface.markdown_island("[upload|#{attachment.upload_id}]", block: false)
    end
  end
end
```

The importer replaces `[upload|<id>]` with the Markdown of the upload once the file is in Discourse. Discourse has to read that as Markdown, so the tag returns the placeholder through `interface.markdown_island`. In most places that is the placeholder as it is. Inside a table that is written as HTML it gets a wrapper, see [HTML mode and placeholders](#html-mode-and-placeholders).

### 4. Put it together

The handler keeps no state, so register it once for all posts. The tag has the attachments of one post, so the renderer is built per post:

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

  # Every AttachmentPlaceholder node in the tree is one placeholder
  # in the Markdown. Store which uploads this post has.
  referenced = result.ast.descendants(ForumMigration::AttachmentPlaceholder)
  store(post, result.markdown, referenced)
end
```

`[attachment]` and `[attach]` are registered with the same handler object. A tag with several names needs that, [Extending Markbridge](/customization/extending/#wrapping-a-default-handler) explains why.

Everywhere else these docs say to build the renderer once. Here it is built per post, because the tag needs data of the post. Keep everything that does not depend on the post outside the loop: the handler registry, an escaper, a postprocessor.

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

# The placeholder nodes of the post.
result.ast.descendants(ForumMigration::AttachmentPlaceholder).map(&:position)
# => [0]
```

Later the importer uploads the file and replaces `[upload|u_screenshot_png_3a7c2]` with the Markdown of the upload.

## A placeholder is not escaped

A placeholder like `[upload|42]` has characters that mean something in Markdown. They are not escaped. Markbridge escapes only `AST::Text` nodes, the text of the source. What a tag returns is written as it is.

So `"[upload|u_screenshot_png_3a7c2]"`, `"@@MENTION:alice@@"` and `"<<TOPIC:7>>"` all arrive in the output unchanged. Choose a form your importer can find again without doubt.

The renderer can add something between a placeholder and its neighbor: a backslash in front of a `!`, or an empty HTML comment (`<!---->`) next to emphasis markers or a mention. It decides that from the characters on both sides. For a placeholder returned as a String, these are the characters of the placeholder, not of what replaces it. The next section shows how to tell the renderer what will stand there.

## Tell Markbridge what replaces the placeholder

In Markdown the characters next to each other decide a lot: whether `**` opens or closes, whether `@alice` is a mention, whether a bare URL becomes a link. The renderer knows these rules and puts an invisible `<!---->` between two pieces where they would go wrong. With a String placeholder it sees the placeholder, not the text the importer puts there later:

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

- The tag returns the placeholder through `interface.markdown_island(text, block: true)`, like the built-in `PollTag` and `EventTag` do. That is the placeholder with a blank line on both sides, `"\n\n[poll|3]\n\n"`, and inside a table the renderer writes as HTML the island form from [HTML mode and placeholders](#html-mode-and-placeholders). Inside a quote or a list item, the quote and the list item tags put `> ` in front of it or indent it like any block.
- The normalizer takes blocks out of bold, italic, links and headings before the renderer runs (see [Normalization](/concepts/normalization/)). It decides that by the AST class: `AST::Poll` and `AST::Event` are blocks. For your own AST class, tell it:

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
    def render(element, interface)
      interface.markdown_island("[poll|#{element.poll_id}]", block: true)
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
  normalizer.rule(parent: container, child: ForumMigration::PollPlaceholder, strategy: :split)
end

Markbridge.render(document, renderer:, normalize: normalizer).markdown
# => "**Vote:**\n\n[poll|3]"
```

Without the rule the placeholder stays inside the bold. Its blank lines split the bold into paragraphs, and every paragraph gets its own markers, so the importer would find `**[poll|3]**`. Pass the same normalizer to every conversion (`normalize:` works on `bbcode_to_markdown` and the other `*_to_markdown` methods too). The same applies to an upload or a link that the importer turns into a block, for example a onebox on its own line: return the block form from the tag and add the rules for its AST class.

### Checklist for a new converter

For every kind of placeholder, whether you write the converter yourself or a coding agent does:

1. **Inline or block?** Decide from what the importer puts there, not from the source tag.
2. **Inline:** return `[Tokens.placeholder(text, like:)]` from the tag. Set `like:` to what the importer will most likely write, or to something that starts and ends with the same kind of character (see the table above).
3. **Block:** return `interface.markdown_island(text, block: true)` from the tag, and make sure the normalizer knows the AST class is a block: a built-in block class, or the rules above.
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

That is the Markdown your importer gives to Discourse.

## HTML mode and placeholders

A table that Markdown cannot express is written as an HTML table: one with a `colspan`, with rows of different length, or with a block in a cell. Inside it, Markdown is not read as Markdown. [CommonMark](https://spec.commonmark.org/0.31.2/#html-blocks) takes everything up to the next blank line as raw HTML. A tag knows that it is inside such a table from `interface.html_mode?`.

A placeholder in such a table has to be written so that its replacement still works there. That is true for a placeholder token too: `Tokens.placeholder` is written as it is in HTML mode. There are two ways:

**Raw HTML.** If what the importer puts there has an HTML form, write that form with the placeholder inside. A link to a profile the importer resolves, for example:

```ruby
module ForumMigration
  class ProfileLinkTag < Markbridge::Renderers::Discourse::Tag
    def render(element, interface)
      placeholder = "[profile|#{element.user_id}]"
      return placeholder unless interface.html_mode?

      # The importer puts a URL there. Inside an HTML block a bare URL
      # is not linked, so the HTML form writes the link.
      %(<a href="#{placeholder}">#{placeholder}</a>)
    end
  end
end
```

**Markdown island.** If what the importer puts there is Markdown without an HTML form, return it through `interface.markdown_island(text, block:)`. Outside an HTML block that is the text itself, with a blank line on both sides when `block: true`. Inside an HTML block it is the text between blank lines inside a `<div>`:

```text
<td><div>

[upload|9]

</div></td>
```

The blank lines close the HTML block, CommonMark parses the placeholder as Markdown, and the `</div>` line opens the block again for the rest of the cell. Bare blank lines are not enough: after them the rest of the cell is Markdown too, until a line opens an HTML block again, and a `~~~` in the text after the placeholder would open a code fence. The shared RSpec example from [Rendering inside HTML blocks](/customization/extending/#rendering-inside-html-blocks) fails a tag that writes a blank line without the `<div>`.

Discourse's upload Markdown is such a case: Discourse reads the dimensions and the `attachment` marker from the Markdown only, and its sanitizer drops the `upload://` href of a raw HTML link. The built-in `UploadTag` writes the island for that reason, the built-in `PollTag` and `EventTag` do it for their BBCode, and the attachment placeholder from above does it already.

The island is a block of its own, with space around it. For a block placeholder like an upload that is fine. For an inline one, a mention or a link, it breaks the line where no break was. Use the raw HTML form for inline placeholders when there is one.

## Collecting more than one kind of placeholder

A migration has several kinds of placeholders: uploads, internal links, mentions. Give each kind its own AST class and ask the tree for each of them:

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

# For example: the links to topics that are not in Discourse yet.
unresolved = links.reject { |link| RESOLVED_TOPICS.key?(link.source_topic_id) }
```

Each call is independent of the others and returns the nodes that are in the Markdown.

## Resolve in the handler or in the tag?

An id of the source has to become an id of Discourse somewhere. That can happen in the handler, while parsing, or in the tag, while rendering:

| In the handler | In the tag |
|---|---|
| The handler looks the value up. The node has the Discourse value. | The handler stores the source value. The tag looks it up. |
| A value that is not found shows while parsing. | A value that is not found shows when you walk the tree afterwards. |
| The tag only writes. | You can look up many values at once, or later. |

A split that works for most migrations: look up in the handler what needs no other post (a path, a user name). Look up in the tag, or in a second pass over `conversion.ast.descendants(...)`, what depends on other posts being imported, like the id of a topic.

## What belongs in the AST node

- **Everything the importer needs to resolve the placeholder:** the position, the original URL, the id in the source, the file name. The node is what you read later, so do not leave out what you will need.
- **Read-only attributes.** Use `attr_reader` and a constructor with keywords, like the built-in nodes.
- **`Element` or `Node`.** Inherit from `Element` when the node has content, like the text of a link. Inherit from `Node` when it has none, like a poll.
- **One class per kind of thing, not per tag name.** `[url]`, `[link]` and `[iurl]` all build an `AST::Url`, and one tag writes all three. Do the same for your placeholders.

## Where next

- [Customizing the renderer](/customization/customizing-renderer/) — every option of the renderer.
- [Extending Markbridge](/customization/extending/) — handlers and tags in general, and how to wrap a default handler.
