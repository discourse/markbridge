---
title: Configuration
description: Global configuration options that apply to all Markbridge conversions.
---

Markbridge has a small global configuration object that controls output behavior. It applies to every `*_to_markdown` convenience method.

## Setting options

```ruby
Markbridge.configure do |config|
  config.escape_hard_line_breaks = true
end
```

Or read and mutate directly:

```ruby
Markbridge.configuration.escape_hard_line_breaks = true
```

## Options

### `escape_hard_line_breaks`

**Type:** `Boolean` — **Default:** `false`

In Markdown, a line ending with two or more trailing spaces becomes a hard line break (`<br>`). This can create surprising output when source content happens to contain trailing whitespace.

When set to `true`, Markbridge strips trailing spaces before newlines so they never produce hard breaks. The default (`false`) matches Discourse's behavior, which preserves the spaces and lets the Markdown renderer decide.

```ruby
Markbridge.configure { |c| c.escape_hard_line_breaks = true }

Markbridge.bbcode_to_markdown("line one   \nline two")
# With true:  "line one\nline two"
# With false: "line one   \nline two"
```

## Per-call overrides

The global configuration is convenient but not the only lever. Every `*_to_markdown` method accepts `handlers:` and `tag_library:` overrides — use those when you need to vary behavior per call rather than globally.

<!-- spec:before
input = "[b]hi[/b]"
my_registry = Markbridge::Parsers::BBCode::HandlerRegistry.default
my_library = Markbridge::Renderers::Discourse::TagLibrary.default
-->
```ruby
Markbridge.bbcode_to_markdown(input, handlers: my_registry, tag_library: my_library)
```

See [Extending Markbridge](/guides/extending/) for how to build custom registries.

## Resetting defaults

Mainly useful in tests:

```ruby
Markbridge.reset_defaults!
```

This clears cached handler registries, the tag library, and the configuration object so the next call rebuilds them.
