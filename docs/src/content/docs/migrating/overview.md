---
title: Migrating to Discourse — overview
description: The mental model for using Markbridge to migrate forum content into Discourse.
---

You have a forum's worth of posts in BBCode, HTML, MediaWiki wikitext, or s9e/TextFormatter XML. You want each post stored on Discourse as Markdown. Most of the body translates straight across — bold text, lists, blockquotes — but a handful of tags need importer-side resolution: internal links to topics that don't exist yet on Discourse, uploads to be shipped, mentions to be looked up, polls and events that map to Discourse plugins. Markbridge is built for exactly that workflow.

This page is the mental model. The next two pages — [Placeholders](/migrating/placeholders/) and [Full walkthrough](/migrating/full-walkthrough/) — fill in the mechanics.

## Four stages

```
source markup ─▶ Parse ─▶ AST ─▶ Render ─▶ Conversion
                                  ▲
                                  └── interface.emit(:key, payload)
                                      side data collected per call
```

1. **Parse**. The format-specific parser tokenizes the input and builds an `AST::Document`. Unknown tags are tracked but never raise — the parser is resilient by design.
2. **AST**. A renderer-agnostic tree of `Text`, `Element`, and leaf nodes (`LineBreak`, `HorizontalRule`). Custom AST nodes (Upload, Mention, InternalLink) live alongside the built-ins.
3. **Render**. The Discourse renderer walks the AST, dispatching each node to its `Tag`. Custom Tags compute placeholder strings *and* emit side data the importer needs after the post is written.
4. **Conversion**. The render produces a `Markbridge::Conversion` value object: rendered Markdown, the AST, format identifier, unknown-tag counts, parser diagnostics, side-data emissions, and any swallowed errors.

The four-stage mental model maps exactly to your importer code: parse-and-resolve happens on the way in (via custom handlers); render-and-emit happens on the way out (via custom Tags); the importer collects emissions per call and writes them to the right tables.

## The Conversion object

Every `*_to_markdown` call returns a `Conversion`:

```ruby
result = Markbridge.bbcode_to_markdown(post.body, renderer: RENDERER)

result.markdown      # the rendered Discourse Markdown
result.ast           # the AST::Document used for rendering
result.format        # :bbcode, :html, :text_formatter_xml, or :mediawiki
result.unknown_tags  # Hash{String => Integer} — tag-name to count
result.diagnostics   # parser-specific diagnostics (e.g. auto-close counts)
result.emissions     # Hash{Symbol => Array} — what custom Tags emitted
result.emitted(:uploads)  # convenience: emissions[:uploads] || []
result.errors        # render-time errors when raise_on_error: false
```

`Conversion#to_s` delegates to `markdown` so `puts result` and `"#{result}"` work without a `.markdown` call. It does *not* delegate other String methods — `result.gsub(...)` raises. Reach for `result.markdown.gsub(...)` or unwrap explicitly.

The same shape comes from `Markbridge.convert(input, format:)` if you're handling multiple formats in one loop.

## Side data: `interface.emit`

A migration importer typically wants to know more than the rendered string. For each placeholder in the post, it needs the resolution data the importer will look up later:

| Tag in source | Placeholder string in markdown | Side data the importer needs |
|---|---|---|
| `[upload=42]` | `[upload\|42]` | `{ upload_id: 42, path: "..." }` |
| `[mention]alice[/mention]` | `[mention\|alice]` | `{ name: "alice", source_id: nil }` |
| `[url=/topics/old-id-7]` | `[topic\|7]` | `{ source_topic_id: 7 }` |

Custom Tags call `interface.emit(:key, payload)` to record this:

```ruby
class UploadTag < Markbridge::Renderers::Discourse::Tag
  def render(element, interface)
    interface.emit(:uploads, id: element.upload_id, path: element.path)
    "[upload|#{element.upload_id}]"
  end
end
```

The importer reads `result.emitted(:uploads)` after the call and writes the upload records before (or after) finalizing the post body. Emissions are buffered per top-level render call, so each post sees only its own side data.

The full pattern lives on the [Placeholders](/migrating/placeholders/) page.

## Unknown tags

Source content rarely covers exactly the tags you've planned for. `Conversion#unknown_tags` (and `Parse#unknown_tags`) gives you the punch list:

```ruby
result.unknown_tags
# => {"marquee" => 3, "blink" => 1, "googletools" => 12}
```

What you do with it is policy:

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

```ruby
posts.each do |post|
  result = Markbridge.bbcode_to_markdown(post.body, renderer: RENDERER, raise_on_error: false)
  if result.errors.any?
    log_failure(post, result.errors)
    next
  end
  write_markdown(post, result.markdown, result.emissions)
end
```

Errors collect on `Conversion#errors` instead of raising. The default stays `raise_on_error: true` so you don't accidentally suppress bugs in unit tests.

## Build the renderer once

Construct a `Renderer` once outside your migration loop and pass it to every call. It carries your custom Tags, the unregistered AST classes you don't want to render, your escaper, and your postprocessor — and its emission buffer resets at the start of each top-level render so emissions never bleed between posts.

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

- [Placeholders](/migrating/placeholders/) — the AST + handler + Tag triad, with the placeholder/emission round-trip end-to-end.
- [Full walkthrough](/migrating/full-walkthrough/) — a runnable mini-importer touching every customization path.
- [Customizing the renderer](/customization/customizing-renderer/) — the full factory reference.
- [Extending Markbridge](/customization/extending/) — adding handlers and custom Tags from scratch.
