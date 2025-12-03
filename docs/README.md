# Markbridge Documentation

Welcome to the Markbridge documentation. This guide will help you understand how Markbridge works and how to use it effectively.

## What is Markbridge?

Markbridge is a Ruby gem that converts BBCode to Discourse-flavored Markdown using a clean **Parse → AST → Render** pipeline. It's designed for forum migrations requiring predictable BBCode handling with graceful degradation for unknown tags.

## Documentation Guide

### Getting Started

- **[Quick Start](../README.md#quick-start)** - Get up and running quickly
- **[Installation](../README.md#installation)** - How to install Markbridge
- **[Examples](../examples/)** - Runnable code examples

### Core Documentation

- **[Architecture Overview](architecture.md)** - Understand the three-phase pipeline and design patterns
- **[Extending Markbridge](extending.md)** - Add custom tags, handlers, and renderers
- **[Performance Guide](performance.md)** - Optimization tips and best practices

#### Parser Documentation

- **[BBCode Parser Guide](parsers/bbcode.md)** - Deep dive into BBCode parsing, handlers, and closing strategies
- **[HTML Parser Guide](parsers/html.md)** - Parse HTML content with Nokogiri
- **[TextFormatter Parser Guide](parsers/text_formatter.md)** - Parse s9e/TextFormatter XML (phpBB 3.2+)
- **[Parser Comparison](parsers/comparison.md)** - Compare BBCode, HTML, and TextFormatter parsers

#### Renderer Documentation

- **[Discourse Renderer Guide](renderers/discourse.md)** - Learn about rendering AST to Markdown with tags and context

### For Developers

- **[CLAUDE.md](../CLAUDE.md)** - Comprehensive guide for AI assistants and contributors
- **[Changelog](../CHANGELOG.md)** - Version history and breaking changes
- **[Contributing](../CONTRIBUTING.md)** - How to contribute to Markbridge

## Quick Reference

### Basic Usage

```ruby
require "markbridge/all"

# Simple conversion
markdown = Markbridge.bbcode_to_markdown("[b]Hello[/b] world!")
# => "**Hello** world!"

# Using the parser and renderer directly
parser = Markbridge::Parsers::BBCode::Parser.new
renderer = Markbridge::Renderers::Discourse::Renderer.new

ast = parser.parse("[b]Hello[/b]")
markdown = renderer.render(ast)
```

### Key Components

| Component | Purpose | Location |
|-----------|---------|----------|
| **Parser** | Converts BBCode to AST | `Markbridge::Parsers::BBCode::Parser` |
| **AST** | Abstract syntax tree | `Markbridge::AST::*` |
| **Renderer** | Converts AST to Markdown | `Markbridge::Renderers::Discourse::Renderer` |
| **Handlers** | Process BBCode tags during parsing | `Markbridge::Parsers::BBCode::Handlers::*` |
| **Tags** | Render AST nodes to Markdown | `Markbridge::Renderers::Discourse::Tags::*` |

### Supported BBCode Tags

| BBCode | Markdown | AST Node |
|--------|----------|----------|
| `[b]...[/b]` | `**...**` | `AST::Bold` |
| `[i]...[/i]` | `*...*` | `AST::Italic` |
| `[s]...[/s]` | `~~...~~` | `AST::Strikethrough` |
| `[u]...[/u]` | `<u>...</u>` | `AST::Underline` |
| `[code]...[/code]` | `` `...` `` or ` ```...``` ` | `AST::Code` |
| `[url=...]...[/url]` | `[...](...)` | `AST::Url` |
| `[list]...[/list]` | `- ...` or `1. ...` | `AST::List` |
| `[*]...` | `- ...` | `AST::ListItem` |
| `[br]` | `\n` | `AST::LineBreak` |
| `[hr]` | `---` | `AST::HorizontalRule` |

See [BBCode Parser Guide](parsers/bbcode.md#supported-tags) for the complete list with all tag aliases.

## Design Philosophy

Markbridge follows these core principles:

- **Graceful degradation** - Unknown tags preserved as text, no parse exceptions
- **Performance-conscious** - O(n) parsing with minimal allocations
- **Extensible** - Handler and Tag registries for customization
- **Clean separation** - Parsing logic separate from rendering logic via AST
- **Test-driven** - Comprehensive unit, integration, and system tests

## Architecture at a Glance

```
BBCode Input → Parser → AST → Renderer → Markdown Output
                 ↓       ↓       ↓
              Scanner  Nodes   Tags
              Handlers        Context
              Registry        Library
```

See [Architecture Overview](architecture.md) for detailed information about each component.

## Common Use Cases

### Forum Migration

```ruby
# Convert forum posts from BBCode to Markdown
posts.each do |post|
  markdown = Markbridge.bbcode_to_markdown(post.content)
  post.update!(content: markdown, format: :markdown)
end
```

### Custom Tag Support

```ruby
# Add support for [quote] tags
parser = Markbridge::Parsers::BBCode::Parser.new do |registry|
  registry.register("quote", QuoteHandler.new)
end

library = Markbridge::Renderers::Discourse::TagLibrary.new
library.auto_register!
library.register(AST::Quote, QuoteTag.new)

renderer = Markbridge::Renderers::Discourse::Renderer.new(tag_library: library)
```

See [Extending Markbridge](extending.md) for complete examples.

## Getting Help

- **Issues** - Report bugs at [GitHub Issues](https://github.com/gschlager/markbridge/issues)
- **Discussions** - Ask questions in [GitHub Discussions](https://github.com/gschlager/markbridge/discussions)
- **Examples** - See `examples/` directory for working code
- **Tests** - Check `spec/` for detailed behavior examples

## Next Steps

1. Read the [Architecture Overview](architecture.md) to understand how Markbridge works
2. Explore the [BBCode Parser Guide](parsers/bbcode.md) to learn about BBCode parsing
3. Review the [Discourse Renderer Guide](renderers/discourse.md) to understand Markdown generation
4. Check out [Extending Markbridge](extending.md) to customize behavior
5. Learn about [Performance Optimization](performance.md) for production use
