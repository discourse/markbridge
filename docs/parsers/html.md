# HTML Parser Guide

This guide explains how the HTML parser converts standard HTML into the Markbridge AST using Nokogiri's HTML parser.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Supported Tags](#supported-tags)
- [Parser Components](#parser-components)
- [Handlers](#handlers)
- [Configuration](#configuration)
- [Examples](#examples)

## Overview

The HTML parser (`Markbridge::Parsers::HTML::Parser`) uses Nokogiri to convert HTML markup into AST. It provides a simpler alternative to the BBCode parser when working with HTML content.

**Key Features:**
- Leverages Nokogiri's battle-tested HTML parser (libxml2 on MRI/TruffleRuby, Xerces/NekoHTML on JRuby)
- Handles malformed HTML gracefully
- Stateless handler API (simpler than BBCode)
- Lambda handler support for quick customization
- Void element detection (self-closing tags)

**Dependencies:**
- Requires the `nokogiri` gem

## Quick Start

### Basic Usage

```ruby
require "markbridge/all"

# Parse HTML to AST
parser = Markbridge::Parsers::HTML::Parser.new
html = "<strong>Hello</strong> <em>world</em>!"
ast = parser.parse(html)

# Render to Markdown
renderer = Markbridge::Renderers::Discourse::Renderer.new
markdown = renderer.render(ast)
# => "**Hello** *world*!"
```

### With Custom Configuration

```ruby
parser = Markbridge::Parsers::HTML::Parser.new do |registry|
  registry.register("custom", CustomHandler.new)
end
```

## Supported Tags

### Formatting Tags

| HTML Tag | AST Node | Notes |
|----------|----------|-------|
| `<strong>`, `<b>` | `AST::Bold` | Bold text |
| `<em>`, `<i>` | `AST::Italic` | Italic text |
| `<del>`, `<s>`, `<strike>` | `AST::Strikethrough` | Strikethrough text |
| `<u>` | `AST::Underline` | Underline text |

### Code Tags

| HTML Tag | AST Node | Notes |
|----------|----------|-------|
| `<code>` | `AST::Code` | Inline or block code |
| `<pre>` | `AST::Code` | Preformatted code block |

### Link Tags

| HTML Tag | AST Node | Notes |
|----------|----------|-------|
| `<a href="...">` | `AST::Url` | Uses `href` attribute |

### List Tags

| HTML Tag | AST Node | Notes |
|----------|----------|-------|
| `<ul>` | `AST::List` | Unordered list |
| `<ol>` | `AST::List` | Ordered list |
| `<li>` | `AST::ListItem` | List item |

### Structure Tags

| HTML Tag | AST Node | Notes |
|----------|----------|-------|
| `<p>` | Paragraph handling | Adds spacing between paragraphs |
| `<br>` | `AST::LineBreak` | Line break |
| `<hr>` | `AST::HorizontalRule` | Horizontal rule |

### Additional Tags

| HTML Tag | AST Node | Notes |
|----------|----------|-------|
| `<blockquote>` | `AST::Quote` | Quote block |
| `<img>` | `AST::Image` | Image with alt text and URL |

## Parser Components

### Parser

**Location:** `Markbridge::Parsers::HTML::Parser`

**Responsibility:** Orchestrate HTML parsing using Nokogiri

**Key Methods:**

```ruby
# Main entry point
ast = parser.parse(html_string)

# Access unknown tags
parser.unknown_tags # => {"unknown" => count}

# Process children (used by handlers)
parser.process_children(nokogiri_element, ast_parent)
```

**Parsing Flow:**
1. Parse HTML with Nokogiri::HTML.fragment
2. Walk DOM tree
3. Dispatch each element to registered handlers
4. Return completed AST::Document

### HandlerRegistry

**Location:** `Markbridge::Parsers::HTML::HandlerRegistry`

**Responsibility:** Map HTML tag names to handlers

**Key Methods:**

```ruby
# Default registry
registry = HandlerRegistry.default

# Custom registry
registry = HandlerRegistry.new
registry.register("custom", CustomHandler.new)

# Build from default
registry = HandlerRegistry.build_from_default do |reg|
  reg.register("custom", CustomHandler.new)
end
```

## Handlers

### Handler Interface

Handlers receive complete DOM elements (stateless API):

```ruby
class CustomHandler < Markbridge::Parsers::HTML::Handlers::BaseHandler
  def initialize(element_class)
    @element_class = element_class
  end

  def process(element:, parent:, processor:)
    # element: Nokogiri::XML::Element (complete DOM element)
    # parent: AST::Element (where to add children)
    # processor: Parser (for processing children)

    ast_element = @element_class.new
    parent << ast_element
    processor.process_children(element, ast_element)
  end

  attr_reader :element_class
end
```

### Built-In Handlers

#### SimpleHandler

For basic formatting tags:

```ruby
handler = SimpleHandler.new(AST::Bold)
registry.register(["b", "strong"], handler)
```

#### RawHandler

For code blocks that preserve content:

```ruby
handler = RawHandler.new
registry.register(["code", "pre"], handler)
```

#### UrlHandler

For links with href attributes:

```ruby
handler = UrlHandler.new
registry.register("a", handler)
```

#### ListHandler & ListItemHandler

For ordered and unordered lists:

```ruby
registry.register(["ul", "ol"], ListHandler.new)
registry.register("li", ListItemHandler.new)
```

### Lambda Handlers

For simple cases, use lambda handlers:

```ruby
registry.register("hr", ->(element:, parent:, **) {
  parent << AST::HorizontalRule.new
  nil # Return nil to skip processing children
})

registry.register("br", ->(element:, parent:, **) {
  parent << AST::LineBreak.new
  nil
})
```

## Configuration

### Block-Based Configuration

```ruby
parser = Markbridge::Parsers::HTML::Parser.new do |registry|
  # Add custom handlers
  registry.register("blockquote", QuoteHandler.new)
  registry.register("span", SpanHandler.new)
end
```

### Using build_from_default

```ruby
registry = HandlerRegistry.build_from_default do |reg|
  reg.register("custom", CustomHandler.new)
end

parser = Parser.new(handlers: registry)
```

## Examples

### Basic Formatting

```ruby
parser = Parser.new
ast = parser.parse("<strong>Bold</strong> and <em>italic</em>")

# AST structure:
# Document
#   ├─ Bold
#   │   └─ Text("Bold")
#   ├─ Text(" and ")
#   └─ Italic
#       └─ Text("italic")
```

### Lists

```ruby
html = <<~HTML
  <ul>
    <li>First item</li>
    <li>Second item</li>
  </ul>
HTML

ast = parser.parse(html)

# AST structure:
# Document
#   └─ List(ordered: false)
#       ├─ ListItem
#       │   └─ Text("First item")
#       └─ ListItem
#           └─ Text("Second item")
```

### Links

```ruby
html = '<a href="https://example.com">Example</a>'
ast = parser.parse(html)

# AST structure:
# Document
#   └─ Url(href: "https://example.com")
#       └─ Text("Example")
```

### Code Blocks

```ruby
html = '<pre><code>def hello\n  puts "world"\nend</code></pre>'
ast = parser.parse(html)

# AST structure:
# Document
#   └─ Code
#       └─ Text("def hello\n  puts \"world\"\nend")
```

### Malformed HTML

The HTML parser handles malformed HTML gracefully through Nokogiri:

```ruby
html = "<b>Unclosed bold <i>and italic</i>"
ast = parser.parse(html)

# Nokogiri auto-closes tags:
# Document
#   └─ Bold
#       ├─ Text("Unclosed bold ")
#       └─ Italic
#           └─ Text("and italic")
```

### Unknown Tags

```ruby
parser = Parser.new
html = "<unknown>content</unknown> <b>bold</b>"
ast = parser.parse(html)

parser.unknown_tags # => {"unknown" => 1}

# AST structure:
# Document
#   ├─ Text("content ")  # Unknown tag wrapper ignored
#   └─ Bold
#       └─ Text("bold")
```

### Custom Handler

```ruby
class CustomHandler < BaseHandler
  def initialize
    @element_class = AST::Custom
  end

  def process(element:, parent:, processor:)
    custom_element = AST::Custom.new(
      data: element["data-custom"]
    )
    parent << custom_element
    processor.process_children(element, custom_element)
  end

  attr_reader :element_class
end

parser = Parser.new do |registry|
  registry.register("custom-tag", CustomHandler.new)
end

html = '<custom-tag data-custom="value">Content</custom-tag>'
ast = parser.parse(html)
```

## Comparison with BBCode Parser

| Feature | HTML Parser | BBCode Parser |
|---------|-------------|---------------|
| Handler complexity | Low (stateless) | High (stateful) |
| Dependencies | Nokogiri | None |
| Malformed input | Handled by Nokogiri | Custom logic |
| Handler API | `process(element:, parent:, processor:)` | `on_open/on_close(token:, context:, registry:)` |
| Lambda support | ✓ | ✗ |
| Parser state access | ✗ | ✓ |
| Look-ahead | ✗ | ✓ |
| Closing strategies | ✗ (Nokogiri handles) | ✓ (Strict/Reordering) |

**When to use HTML Parser:**
- Converting HTML content to Markdown
- Web scraping to Markdown
- HTML email content
- Simpler handler requirements
- Need robust malformed HTML handling

**When to use BBCode Parser:**
- Forum migrations (BBCode native format)
- Zero dependencies required
- Need fine-grained parsing control
- Custom closing logic needed

## Next Steps

- **[BBCode Parser Guide](bbcode.md)** - Compare with BBCode parser
- **[Parser Comparison](comparison.md)** - Detailed comparison of all parsers
- **[Discourse Renderer Guide](../renderers/discourse.md)** - Learn about rendering
- **[Extending Markbridge](../extending.md)** - Add custom handlers
