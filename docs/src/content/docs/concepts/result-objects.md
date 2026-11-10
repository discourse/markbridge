---
title: Result objects
description: Read Markdown, AST nodes, unknown tags, and diagnostics from Conversion and Parse results.
---

A conversion gives you more than Markdown. You also get the tree it was written from, the tags the parser did not know, and notes about what the parser had to repair. For that reason `Markbridge.*_to_markdown` returns a `Conversion` object, not a String, and `Markbridge.parse_*` returns a `Parse`.

## Conversion

`Markbridge.*_to_markdown` and `Markbridge.convert` return a `Markbridge::Conversion`:

<!-- spec:before
RENDERER = Markbridge.discourse_renderer
post = Struct.new(:body).new("[b]hi[/b]")
-->
```ruby
result = Markbridge.bbcode_to_markdown(post.body, renderer: RENDERER)

result.markdown      # the rendered Discourse Markdown
result.ast           # the AST::Document used for rendering
result.format        # :bbcode, :html, :text_formatter_xml, or :mediawiki
result.unknown_tags  # Hash{String => Integer} — tag name to count
result.diagnostics   # parser-specific diagnostics (e.g. auto-close counts)
result.errors        # render-time errors, when raise_on_error: false
```

`Conversion#to_s` returns the Markdown, so `puts result` and `"#{result}"` work. Other String methods are not there: `result.gsub(...)` raises. Call `result.markdown.gsub(...)`.

`Markbridge.convert(input, format:)` returns the same `Conversion`. Use it when the format is only known at run time, for example when your posts are in more than one format:

<!-- spec:before
RENDERER = Markbridge.discourse_renderer
posts = [
  { body: "[b]hi[/b]", format: :bbcode },
  { body: "<b>hi</b>", format: :html },
]
-->
```ruby
posts.each do |post|
  result = Markbridge.convert(post[:body], format: post[:format], renderer: RENDERER)
  # use result.markdown…
end
```

## Parse

Every `*_to_markdown` method has a `parse_*` method that stops after parsing. It returns a `Markbridge::Parse`: what a `Conversion` has, without `markdown` and without `errors`, which only rendering can have.

<!-- spec:before
input = "[b]hi[/b]"
-->
```ruby
parse = Markbridge.parse_bbcode(input)

parse.ast           # the AST::Document
parse.format        # :bbcode
parse.unknown_tags  # Hash{String => Integer}
parse.diagnostics   # parser-specific diagnostics
```

Use `parse_*` to look at the tree or to change it before rendering. `Markbridge.render(parse, renderer:)` renders a `Parse` and returns a `Conversion`, with the `format`, `unknown_tags` and `diagnostics` of the parse.

## What the fields mean

- **`unknown_tags`** has the tags no handler was registered for, with a count each. The parser does not raise on them. Whether a post with unknown tags is fine, gets logged, or fails is your decision.
- **`diagnostics`** has what the parser had to repair. The BBCode parser reports how many tags it closed itself (`auto_closed_tags_count`), how many it left as text because they were nested too deep (`depth_exceeded_count`), and code tags that were never closed (`unclosed_raw_tags`). The key `:normalization` lists what the [normalizer](/concepts/normalization/) rewrote. It is missing when nothing changed.
- **`errors`** has the errors of rendering when you pass `raise_on_error: false`. Without that option an error is raised and the list stays empty. In a migration, expect `Markbridge::UndecidedFeatureError`: a post has a color or a size, and the renderer was not told whether the site has the discourse-bbcode plugin (see [`features:`](/customization/customizing-renderer/#features--the-plugins-of-the-target-site)).
