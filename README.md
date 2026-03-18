# Markbridge

Markbridge converts BBCode into Discourse-flavored Markdown through a clean parse → AST → render pipeline. It is intended for forum migrations and any workflow that needs predictable BBCode handling.

## How it works

1. **Parse BBCode** – `Markbridge::Parsers::BBCode::Parser` tokenizes input and builds an `AST::Document`, reconciling nesting and collecting raw content where needed.
2. **Transform AST** – The AST captures semantic nodes such as text, formatting elements, lists, URLs, and code blocks that are renderer-agnostic.
3. **Render to Markdown** – `Markbridge::Renderers::Discourse::Renderer` walks the tree with a tag library to emit Discourse-compatible Markdown, then normalizes spacing for final output.

Refer to the component guides for more detail:

* [BBCode parser](docs/parsers/bbcode.md)
* [Discourse renderer](docs/renderers/discourse.md)

## Installation

Add the gem to your project:

```bash
bundle add markbridge
```

Or install it directly:

```bash
gem install markbridge
```

## Quick start

```ruby
require "markbridge/all"

bbcode = "[b]Hello[/b] [url=https://example.com]world[/url]!"
markdown = Markbridge.bbcode_to_markdown(bbcode)

puts markdown
# => "**Hello** [world](https://example.com)!"
```

## Learn more

* See `examples/` for runnable scripts such as `examples/basic_usage.rb`.
* Browse integration and unit coverage under `spec/` to understand supported tags and edge cases.
* Use `bin/console` during development for interactive exploration.
* Use `bin/playground` during development to inspect BBCode, HTML, and TextFormatter XML conversions in a local web UI.
