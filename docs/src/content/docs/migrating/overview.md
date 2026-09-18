---
title: Migrating to Discourse — overview
description: The big picture for using Markbridge to migrate forum content into Discourse.
---

You have a forum's worth of posts in BBCode, HTML, MediaWiki wikitext, or s9e/TextFormatter XML, and you want each one stored on Discourse as Markdown. Most of the body translates straight across — bold text, lists, headings — but a few tags need more than that: internal links to topics that don't exist on Discourse yet, uploads to ship, mentions to look up, polls and events that map to Discourse plugins. That awkward last mile is exactly what Markbridge is built for.

This page is the big picture. The next page — [Placeholders](/migrating/placeholders/) — fills in the details.

## How a migration uses the pipeline

Every conversion runs the same parse → AST → render pipeline — the [Introduction](/introduction/) covers it. A migration wraps three points around that pipeline:

- **On the way in**, custom handlers turn source tags into AST nodes — including your own nodes for uploads, mentions, and internal links.
- **On the way out**, custom Tags format each node. A placeholder Tag is a one-line formatter that returns its placeholder string and nothing else.
- **After the conversion**, you walk the AST to collect what each post referenced and write it into Discourse.

That last step — the read-back — is the heart of the workflow; the [Placeholders](/migrating/placeholders/) page covers it in full.

## What you get back

Every `*_to_markdown` call — and `Markbridge.convert`, which dispatches by `format:` when a corpus mixes formats — returns a [`Conversion`](/concepts/result-objects/): the rendered `markdown` plus the `ast`, `unknown_tags`, `diagnostics`, and `errors`. The rest of this page leans on those fields; [Result objects](/concepts/result-objects/) covers the full shape.

## Side data: read it back off the AST

A migration usually needs more than the rendered string. For each placeholder in a post, you also need the data to resolve it later:

| Tag in source | Placeholder string in markdown | Side data to resolve later |
|---|---|---|
| `[upload=42]` | `[upload\|42]` | `{ upload_id: 42, path: "..." }` |
| `[mention]alice[/mention]` | `[mention\|alice]` | `{ name: "alice", source_id: nil }` |
| `[url=/topics/old-id-7]` | `[topic\|7]` | `{ source_topic_id: 7 }` |

You don't need a side channel for this. The custom AST node carries the parsed data, and `conversion.ast` is the exact tree that produced the Markdown — so the Tag stays a pure formatter:

```ruby
class UploadTag < Markbridge::Renderers::Discourse::Tag
  def render(element, _interface)
    "[upload|#{element.upload_id}]"
  end
end
```

After the conversion, collect every upload the post referenced by walking the tree for your placeholder class. (In real use, `result` comes from a `*_to_markdown` call; here we build a one-node tree by hand to keep the snippet self-contained.)

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

`descendants(klass)` walks the whole tree (leaf nodes included) and returns the nodes that survived parsing — exactly the placeholders that reached the output, for this one conversion only. Nothing leaks between posts, because each call has its own `ast`. The three pieces that make this work — the AST node, the handler, and the Tag — are explained on the [Placeholders](/migrating/placeholders/) page.

## Unknown tags

Source content rarely covers exactly the tags you've planned for. `Conversion#unknown_tags` (and `Parse#unknown_tags`) gives you the punch list:

<!-- spec:before
result = Markbridge.bbcode_to_markdown("[marquee]hi[/marquee]")
-->
```ruby
result.unknown_tags
# => {"marquee" => 3, "blink" => 1, "googletools" => 12}
```

What you do with it is policy:

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

Aggregate across the corpus to find which tags are worth writing handlers for, which to silently drop, and which to fail on. Markbridge never raises for an unknown tag — that decision belongs to your migration script.

## Per-post failure isolation

Forum corpora contain edge cases that surface only when you migrate them. By default, render-time errors propagate; a single bad post crashes the loop. Pass `raise_on_error: false` to flip that:

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

Errors collect on `Conversion#errors` instead of raising. The default stays `raise_on_error: true` so you don't accidentally suppress bugs in unit tests.

## Build the renderer once

Construct a `Renderer` once outside your migration loop and pass it to every call. It carries your custom Tags, the unregistered AST classes you don't want to render, your escaper, and your postprocessor. It holds no per-post state, so the same instance is safe across thousands of posts.

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

See [Customizing the renderer](/customization/customizing-renderer/) for every kwarg.

## Where next

- [Placeholders](/migrating/placeholders/) — the AST node, handler, and Tag in detail, with the full round-trip.
- [Customizing the renderer](/customization/customizing-renderer/) — the full factory reference.
- [Extending Markbridge](/customization/extending/) — adding handlers and custom Tags from scratch.
