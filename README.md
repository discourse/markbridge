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

## Configuration

```ruby
Markbridge.configure do |config|
  # Strip trailing spaces before newlines to prevent hard line breaks (<br/>).
  # Defaults to false (Discourse has this disabled by default).
  config.escape_hard_line_breaks = true
end
```

Configuration applies to all `*_to_markdown` convenience methods (`bbcode_to_markdown`, `html_to_markdown`, etc.).

## Learn more

* See `examples/` for runnable scripts such as `examples/basic_usage.rb`.
* Browse integration and unit coverage under `spec/` to understand supported tags and edge cases.
* Use `bin/console` during development for interactive exploration.

## Development

This repository is set up to run inside [silo](https://github.com/gschlager/silo), a lightweight dev-environment tool. The `.silo.yml` file provisions a Fedora container with JRuby and multiple CRuby versions (via [rv](https://rv.dev)), installs dependencies, and starts the playground daemon. If you prefer your own setup, `bin/setup` and `bundle install` are all you need.

## Playground

A local web UI for exploring parsers interactively:

```bash
bin/playground
```

Open `http://127.0.0.1:4567` to select a parser (BBCode, HTML, TextFormatter XML, MediaWiki), pick an example, edit the input, and inspect the AST tree and Markdown output. Keyboard shortcuts: `1` Input, `2` Output, `3` AST, `Cmd/Ctrl+Enter` to render.
