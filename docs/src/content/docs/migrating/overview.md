---
title: Migrating to Discourse — overview
description: How a forum migration to Discourse uses Markbridge, from the post in the old database to Markdown.
---

You have the posts of a forum in BBCode, HTML, MediaWiki wikitext or s9e\TextFormatter XML, and every one of them has to become Markdown in Discourse.

Most of a post converts by itself: bold text, lists, quotes, code. The hard part is what points to other things:

- a link to a topic that is not in Discourse yet,
- an attachment that has to be uploaded first,
- a mention of a user whose name changes in the migration,
- a poll or an event, which are plugins in Discourse.

Markbridge cannot resolve these, because only your importer knows the new ids. What it does is keep them findable: it writes a placeholder into the Markdown and gives you the node with the data. This page shows how a migration is put together. [Placeholders](/migrating/placeholders/) has the details.

## How a migration uses the pipeline

Every conversion parses the input into a tree, the AST, and renders the tree (see the [Introduction](/introduction/)). A migration adds its own code in three places:

1. **In the parser.** Your handlers turn the tags of the source into AST nodes, also into your own nodes for uploads, mentions and internal links.
2. **In the renderer.** Your tags write these nodes. A tag for a placeholder is short: it returns the placeholder text.
3. **After the conversion.** You walk the tree, collect what the post points to, and resolve it in your importer.

Every `*_to_markdown` call returns a [`Conversion`](/concepts/result-objects/) with what the three steps need: `markdown`, `ast`, `unknown_tags`, `diagnostics` and `errors`.

## Placeholders and their data

For every placeholder in a post, the importer needs the data to resolve it later:

| Tag in the source | Placeholder in the Markdown | Data to resolve it |
|---|---|---|
| `[upload=42]` | `[upload\|42]` | `{ upload_id: 42, path: "..." }` |
| `[mention]alice[/mention]` | `[mention\|alice]` | `{ name: "alice", source_id: nil }` |
| `[url=/topics/old-id-7]` | `[topic\|7]` | `{ source_topic_id: 7 }` |

You do not have to collect that data while the post renders. Your AST node has it, and `conversion.ast` is the tree the Markdown was written from. So the tag only writes the placeholder:

```ruby
class UploadTag < Markbridge::Renderers::Discourse::Tag
  def render(element, _interface)
    "[upload|#{element.upload_id}]"
  end
end
```

After the conversion, ask the tree for all nodes of your class. In this example the tree is built by hand to keep it short. In your importer, `result` comes from a `*_to_markdown` call:

<!-- spec:before
def record_upload(**); end
-->
```ruby
class UploadPlaceholder < Markbridge::AST::Node
  attr_reader :upload_id, :path
  def initialize(upload_id:, path:)
    @upload_id = upload_id
    @path = path
  end
end

document = Markbridge::AST::Document.new
document << UploadPlaceholder.new(upload_id: 42, path: "files/cat.png")
result = Markbridge.render(document)

result.ast.descendants(UploadPlaceholder).each do |node|
  record_upload(id: node.upload_id, path: node.path)
end
```

`descendants(klass)` returns every node of the class in the tree. These are the placeholders in the Markdown of this post and of no other, because every conversion has its own tree. [Placeholders](/migrating/placeholders/) explains the node, the handler and the tag.

## Unknown tags

A forum always has tags you did not plan for: from a plugin that was removed years ago, or typed by hand. The parser drops such a tag, keeps its content, and counts it in `unknown_tags`:

<!-- spec:before
result = Markbridge.bbcode_to_markdown("[marquee]hi[/marquee]")
-->
```ruby
result.unknown_tags
# => {"marquee" => 3, "blink" => 1, "googletools" => 12}
```

Log the counts for every post:

<!-- spec:before
RENDERER = Markbridge.discourse_renderer
def log(_msg); end
posts = [Struct.new(:id, :body).new(1, "[b]hi[/b]")]
-->
```ruby
posts.each do |post|
  result = Markbridge.bbcode_to_markdown(post.body, renderer: RENDERER)
  result.unknown_tags.each do |tag, count|
    log "post #{post.id}: unknown tag [#{tag}] x#{count}"
  end
end
```

Add them up over all posts before the real migration. The list shows which tags are common enough for a handler and which you can drop. Markbridge never raises for an unknown tag. Whether a post with one is fine is your decision.

## One bad post must not stop the run

Among millions of posts there is always one that makes a tag of yours raise. By default the error is raised, and your loop ends at that post. With `raise_on_error: false` the errors are collected in `result.errors`:

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
    next
  end
  write_markdown(post, result.markdown)
end
```

The default is `true` on purpose: in your tests an error should be raised, not collected.

## Build the renderer once

Build one renderer in front of the loop and pass it to every call. It has your tags and your options, and it keeps nothing from one post to the next. Use one per thread.

<!-- spec:before
InternalLinkTag = UploadTag = MentionTag = Class.new(Markbridge::Renderers::Discourse::Tag) do
  def render(element, interface) = interface.render_children(element)
end
posts = [Struct.new(:body).new("[b]hi[/b]")]
-->
```ruby
RENDERER = Markbridge.discourse_renderer(
  tags: {
    Markbridge::AST::Url => InternalLinkTag.new,
    Markbridge::AST::Upload => UploadTag.new,
    Markbridge::AST::Mention => MentionTag.new,
  },
  unregister: [Markbridge::AST::Color, Markbridge::AST::Size],
  escape_hard_line_breaks: true,
)

posts.each do |post|
  result = Markbridge.bbcode_to_markdown(post.body, renderer: RENDERER)
  # ...
end
```

[Customizing the renderer](/customization/customizing-renderer/) lists every option. Two of them matter for nearly every migration:

- **`features:`** says which plugins the target site has, so that a spoiler, a details block, a poll or a color is written in a form the site can show. Colors and sizes raise an error until you decide.
- **`base_url:`** is the address of the old forum. Relative links and images are made absolute with it. Without it Discourse drops them.

## Where next

- [Placeholders](/migrating/placeholders/) — the node, the handler and the tag for a placeholder, step by step.
- [Customizing the renderer](/customization/customizing-renderer/) — every option of the renderer.
- [Extending Markbridge](/customization/extending/) — handlers and tags for the tags only your forum has.
