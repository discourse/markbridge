---
title: Result objects
description: What Markbridge hands back — the Conversion from *_to_markdown, and the Parse from parse_*.
---

Markbridge's convenience methods don't return a plain string. The render methods return a `Conversion`; the parse-only methods return a `Parse`. Both carry their data alongside the result, so you never need a side channel.

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

`Conversion#to_s` delegates to `markdown`, so `puts result` and `"#{result}"` work without a `.markdown` call. It does *not* delegate other String methods — `result.gsub(...)` raises. Reach for `result.markdown.gsub(...)` or unwrap explicitly.

`Markbridge.convert(input, format:)` returns the same `Conversion`, dispatching to the right `*_to_markdown` method — handy when one corpus mixes formats:

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

Each `*_to_markdown` has a matching `parse_*` that stops after building the AST. It returns a `Markbridge::Parse` — everything a `Conversion` has except the rendered `markdown` (and `errors`, which are render-time):

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

Reach for `parse_*` when you want to inspect or transform the tree before rendering, or render it yourself with a custom renderer. Hand a `Parse` to `Markbridge.render(parse, renderer:)` to get a `Conversion` back (the source `format`, `unknown_tags`, and `diagnostics` carry through).

## What the fields mean

- **`unknown_tags`** — tags the parser didn't recognize, with a count each. The parser never raises on them; what you do with the list is your call.
- **`diagnostics`** — parser-specific notes (auto-closed tags, depth limits hit, unclosed raw tags, and so on).
- **`errors`** — render-time errors collected instead of raised, when you pass `raise_on_error: false`. Empty otherwise.
