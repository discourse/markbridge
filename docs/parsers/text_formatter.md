# TextFormatter Parser Guide

This guide explains how the TextFormatter parser converts s9e/TextFormatter XML format into the Markbridge AST. This parser is designed specifically for phpBB 3.2+ migrations and other forum software using the s9e/TextFormatter library.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [s9e/TextFormatter Format](#s9etextformatter-format)
- [Supported Elements](#supported-elements)
- [Parser Components](#parser-components)
- [Handlers](#handlers)
- [Configuration](#configuration)
- [Examples](#examples)

## Overview

The TextFormatter parser (`Markbridge::Parsers::TextFormatter::Parser`) parses XML output from the [s9e/TextFormatter](https://github.com/s9e/TextFormatter) library, which is used by phpBB 3.2+ and other modern forum software.

**Key Features:**
- Parses s9e/TextFormatter XML format
- Handles s9e conventions (uppercase element names, `<s>`/`<e>` markup)
- Stateless handler API (simple)
- Lambda handler support
- Fallback to plain text for invalid XML
- Built on Nokogiri XML parser

**Dependencies:**
- Requires the `nokogiri` gem

**Primary Use Case:**
- phpBB 3.2+ forum migrations
- Any software using s9e/TextFormatter for BBCode storage

## Quick Start

### Basic Usage

```ruby
require "markbridge/all"

# Parse s9e/TextFormatter XML to AST
parser = Markbridge::Parsers::TextFormatter::Parser.new
xml = '<r><B><s>[b]</s>Hello<e>[/b]</e></B> world!</r>'
ast = parser.parse(xml)

# Render to Markdown
renderer = Markbridge::Renderers::Discourse::Renderer.new
markdown = renderer.render(ast)
# => "**Hello** world!"
```

### With Custom Configuration

```ruby
parser = Markbridge::Parsers::TextFormatter::Parser.new do |registry|
  registry.register("CUSTOM", CustomHandler.new)
end
```

## s9e/TextFormatter Format

### Format Overview

s9e/TextFormatter stores BBCode as XML with two formats:

#### Plain Text Format
```xml
<t>This is plain text content</t>
```

#### Rich Text Format
```xml
<r>
  <B>bold text</B>
  <URL url="https://example.com">link</URL>
  more text
</r>
```

### Special Elements

#### Root Elements
- `<t>` - Plain text wrapper (no BBCode)
- `<r>` - Rich text wrapper (contains formatted content)

#### Markup Preservation Elements
- `<s>` - Start markup (e.g., `<s>[b]</s>`)
- `<e>` - End markup (e.g., `<e>[/b]</e>`)

These elements preserve the original BBCode for unparsing but are **ignored during parsing**.

#### Line Breaks
- `<br/>` - Line break element

### Naming Convention

**Element names are UPPERCASE** (s9e convention):
- `<B>` for bold (not `<b>`)
- `<URL>` for links (not `<url>`)
- `<CODE>` for code (not `<code>`)

## Supported Elements

### Formatting Elements

| XML Element | AST Node | Example |
|-------------|----------|---------|
| `<B>` | `AST::Bold` | `<B>bold</B>` |
| `<I>` | `AST::Italic` | `<I>italic</I>` |
| `<U>` | `AST::Underline` | `<U>underline</U>` |
| `<S>` | `AST::Strikethrough` | `<S>strike</S>` |

### Code Elements

| XML Element | AST Node | Example |
|-------------|----------|---------|
| `<CODE>` | `AST::Code` | `<CODE lang="ruby">code</CODE>` |

**Attributes:**
- `lang` - Language hint for syntax highlighting

### Link Elements

| XML Element | AST Node | Example |
|-------------|----------|---------|
| `<URL>` | `AST::Url` | `<URL url="https://example.com">text</URL>` |
| `<EMAIL>` | `AST::Url` | `<EMAIL email="user@example.com">text</EMAIL>` |

**Attributes:**
- `url` - Link destination for URLs
- `email` - Email address for email links

### List Elements

| XML Element | AST Node | Example |
|-------------|----------|---------|
| `<LIST>` | `AST::List` | `<LIST><LI>item</LI></LIST>` |
| `<LI>` | `AST::ListItem` | `<LI>list item</LI>` |

**Attributes:**
- `type` - List type ("bullet" or "decimal")

### Structure Elements

| XML Element | AST Node | Example |
|-------------|----------|---------|
| `<br/>` | `AST::LineBreak` | `text<br/>more` |
| `<HR>` | `AST::HorizontalRule` | `<HR/>` |

### Additional Elements

| XML Element | AST Node | Example |
|-------------|----------|---------|
| `<QUOTE>` | `AST::Quote` | `<QUOTE author="John">text</QUOTE>` |
| `<IMG>` | `AST::Image` | `<IMG src="url.jpg" alt="text"/>` |

## Parser Components

### Parser

**Location:** `Markbridge::Parsers::TextFormatter::Parser`

**Responsibility:** Parse s9e/TextFormatter XML using Nokogiri

**Key Methods:**

```ruby
# Main entry point
ast = parser.parse(xml_string)

# Access unknown tags
parser.unknown_tags # => {"UNKNOWN" => count}

# Process children (used by handlers)
parser.process_children(xml_element, ast_parent)
```

**Parsing Flow:**
1. Parse XML with Nokogiri::XML
2. Walk XML tree
3. Filter out `<s>` and `<e>` elements
4. Handle root elements (`<t>`, `<r>`)
5. Dispatch elements to handlers
6. Return completed AST::Document

**Error Handling:**
- Invalid XML falls back to plain text
- Parsing errors return content as `AST::Text`

### HandlerRegistry

**Location:** `Markbridge::Parsers::TextFormatter::HandlerRegistry`

**Responsibility:** Map XML element names to handlers

**Key Methods:**

```ruby
# Default registry
registry = HandlerRegistry.default

# Custom registry
registry = HandlerRegistry.new
registry.register("CUSTOM", CustomHandler.new)

# Build from default
registry = HandlerRegistry.build_from_default do |reg|
  reg.register("CUSTOM", CustomHandler.new)
end
```

## Handlers

### Handler Interface

Handlers receive complete XML elements (stateless API):

```ruby
class CustomHandler < Markbridge::Parsers::TextFormatter::Handlers::BaseHandler
  def initialize(element_class)
    @element_class = element_class
  end

  def process(element:, parent:, processor:)
    # element: Nokogiri::XML::Element
    # parent: AST::Element
    # processor: Parser instance

    # Extract attributes using helper
    attrs = extract_attributes(element)

    ast_element = @element_class.new(custom: attrs[:custom])
    parent << ast_element
    processor.process_children(element, ast_element)
  end

  attr_reader :element_class
end
```

### Attribute Extraction Helper

BaseHandler provides an `extract_attributes` helper:

```ruby
def process(element:, parent:, processor:)
  attrs = extract_attributes(element)
  # Returns hash with symbolized keys: { url: "...", lang: "..." }

  ast_element = @element_class.new(url: attrs[:url])
  # ...
end
```

### Built-In Handlers

#### SimpleHandler

For basic formatting elements:

```ruby
handler = SimpleHandler.new(AST::Bold)
registry.register("B", handler)
```

#### CodeHandler

For code blocks with language support:

```ruby
handler = CodeHandler.new
registry.register("CODE", handler)
```

#### UrlHandler

For links and email addresses:

```ruby
handler = UrlHandler.new
registry.register("URL", handler)

email_handler = EmailHandler.new
registry.register("EMAIL", email_handler)
```

#### ListHandler

For lists with type detection:

```ruby
handler = ListHandler.new
registry.register("LIST", handler)
```

### Lambda Handlers

For simple cases:

```ruby
registry.register("HR", ->(element:, parent:, **) {
  parent << AST::HorizontalRule.new
  nil # Return nil to skip children
})
```

## Configuration

### Block-Based Configuration

```ruby
parser = Markbridge::Parsers::TextFormatter::Parser.new do |registry|
  # Add custom handlers
  registry.register("CUSTOM", CustomHandler.new)
  registry.register("SPOILER", SpoilerHandler.new)
end
```

### Using build_from_default

```ruby
registry = HandlerRegistry.build_from_default do |reg|
  reg.register("CUSTOM", CustomHandler.new)
end

parser = Parser.new(handlers: registry)
```

## Examples

### Plain Text

```ruby
parser = Parser.new
xml = '<t>This is plain text</t>'
ast = parser.parse(xml)

# AST structure:
# Document
#   └─ Text("This is plain text")
```

### Basic Formatting

```ruby
xml = '<r><B>Bold</B> and <I>italic</I></r>'
ast = parser.parse(xml)

# AST structure:
# Document
#   ├─ Bold
#   │   └─ Text("Bold")
#   ├─ Text(" and ")
#   └─ Italic
#       └─ Text("italic")
```

### With Markup Preservation

```ruby
xml = '<r><B><s>[b]</s>Hello<e>[/b]</e></B> world!</r>'
ast = parser.parse(xml)

# <s> and <e> elements are ignored during parsing
# AST structure:
# Document
#   ├─ Bold
#   │   └─ Text("Hello")
#   └─ Text(" world!")
```

### Links

```ruby
xml = '<r><URL url="https://example.com">Example</URL></r>'
ast = parser.parse(xml)

# AST structure:
# Document
#   └─ Url(href: "https://example.com")
#       └─ Text("Example")
```

### Code Blocks

```ruby
xml = '<r><CODE lang="ruby"><s>[code=ruby]</s>def hello
  puts "world"
end<e>[/code]</e></CODE></r>'

ast = parser.parse(xml)

# AST structure:
# Document
#   └─ Code(language: "ruby")
#       └─ Text("def hello\n  puts \"world\"\nend")
```

### Lists

```ruby
xml = '<r><LIST type="bullet"><LI>First</LI><LI>Second</LI></LIST></r>'
ast = parser.parse(xml)

# AST structure:
# Document
#   └─ List(ordered: false)
#       ├─ ListItem
#       │   └─ Text("First")
#       └─ ListItem
#           └─ Text("Second")
```

### Nested Elements

```ruby
xml = '<r><B>Bold with <I>italic</I> inside</B></r>'
ast = parser.parse(xml)

# AST structure:
# Document
#   └─ Bold
#       ├─ Text("Bold with ")
#       ├─ Italic
#       │   └─ Text("italic")
#       └─ Text(" inside")
```

### Invalid XML

```ruby
parser = Parser.new
xml = 'This is not valid XML <tag'
ast = parser.parse(xml)

# Falls back to plain text:
# Document
#   └─ Text("This is not valid XML <tag")
```

### Unknown Elements

```ruby
parser = Parser.new
xml = '<r><UNKNOWN>content</UNKNOWN> <B>bold</B></r>'
ast = parser.parse(xml)

parser.unknown_tags # => {"UNKNOWN" => 1}

# AST structure:
# Document
#   ├─ Text("content ")  # Unknown wrapper ignored
#   └─ Bold
#       └─ Text("bold")
```

### Custom Handler

```ruby
class SpoilerHandler < BaseHandler
  def initialize
    @element_class = AST::Spoiler
  end

  def process(element:, parent:, processor:)
    spoiler = AST::Spoiler.new
    parent << spoiler
    processor.process_children(element, spoiler)
  end

  attr_reader :element_class
end

parser = Parser.new do |registry|
  registry.register("SPOILER", SpoilerHandler.new)
end

xml = '<r><SPOILER>Hidden content</SPOILER></r>'
ast = parser.parse(xml)
```

## phpBB Migration Notes

### phpBB Version Support

- **phpBB 3.2+** - Uses s9e/TextFormatter (use this parser)
- **phpBB 3.1 and earlier** - Uses traditional BBCode (use BBCode parser)

### Getting XML from phpBB

phpBB stores messages in XML format in the `message` column:

```sql
SELECT post_id, message FROM phpbb_posts WHERE post_id = 123;
```

Example output:
```xml
<r>
  <B><s>[b]</s>Hello<e>[/b]</e></B> world!
</r>
```

### Migration Workflow

```ruby
require "markbridge/all"

parser = Markbridge::Parsers::TextFormatter::Parser.new
renderer = Markbridge::Renderers::Discourse::Renderer.new

# Fetch posts from phpBB
posts = database.execute("SELECT post_id, message FROM phpbb_posts")

posts.each do |post|
  # Parse s9e XML
  ast = parser.parse(post[:message])

  # Render to Discourse Markdown
  markdown = renderer.render(ast)

  # Save to Discourse
  discourse_post = DiscoursePost.create!(
    content: markdown,
    # ... other fields
  )
end
```

## Comparison with Other Parsers

| Feature | TextFormatter | BBCode | HTML |
|---------|---------------|--------|------|
| Input format | s9e/TextFormatter XML | BBCode | HTML |
| Dependencies | Nokogiri | None | Nokogiri |
| Handler complexity | Low (stateless) | High (stateful) | Low (stateless) |
| Element names | UPPERCASE | lowercase | lowercase |
| Malformed input | Fallback to text | Custom logic | Nokogiri handles |
| Lambda support | ✓ | ✗ | ✓ |
| Primary use case | phpBB 3.2+ | Forum migrations | HTML content |

**When to use TextFormatter Parser:**
- phpBB 3.2+ migrations
- Software using s9e/TextFormatter
- You have s9e XML format

**When to use other parsers:**
- **BBCode Parser** - Traditional BBCode, no dependencies, fine control
- **HTML Parser** - HTML content, web scraping

## Next Steps

- **[BBCode Parser Guide](bbcode.md)** - Compare with BBCode parser
- **[HTML Parser Guide](html.md)** - Compare with HTML parser
- **[Parser Comparison](comparison.md)** - Detailed comparison of all parsers
- **[Discourse Renderer Guide](../renderers/discourse.md)** - Learn about rendering
- **[Extending Markbridge](../extending.md)** - Add custom handlers
