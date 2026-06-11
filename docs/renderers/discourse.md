# Discourse Renderer Guide

This comprehensive guide explains how the Discourse renderer converts Markbridge AST into Discourse-flavored Markdown, including tags, context, rendering interface, and configuration.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Renderer Types](#renderer-types)
- [Core Components](#core-components)
- [Rendering Tags](#rendering-tags)
- [AST to Markdown Mapping](#ast-to-markdown-mapping)
- [Context-Aware Rendering](#context-aware-rendering)
- [Configuration](#configuration)
- [Examples](#examples)

## Overview

The Discourse renderer (`Markbridge::Renderers::Discourse::Renderer`) walks the AST tree and generates Discourse-flavored Markdown. It uses a tag library to map AST element classes to renderers and provides context for parent-aware rendering decisions.

**Key Features:**
- Clean separation via RenderingInterface
- O(1) parent lookups with cached context
- Auto-registration of tags
- Fallback rendering for unknown nodes
- Smart marker wrapping (avoids double-marking)

## Quick Start

### Basic Usage

```ruby
require "markbridge/all"

# Simple rendering
renderer = Markbridge::Renderers::Discourse::Renderer.new
ast = Markbridge::AST::Document.new([
  Markbridge::AST::Bold.new([
    Markbridge::AST::Text.new("Hello")
  ])
])
markdown = renderer.render(ast)
# => "**Hello**"

# Or use the convenience method
markdown = Markbridge.bbcode_to_markdown("[b]Hello[/b]")
# => "**Hello**"
```

### With Custom Configuration

```ruby
library = Markbridge::Renderers::Discourse::TagLibrary.new
library.auto_register! # Auto-discover tags

# Override specific tag
library.register(AST::Underline, CustomUnderlineTag.new)

renderer = Markbridge::Renderers::Discourse::Renderer.new(tag_library: library)
```

## Renderer Types

**In-Memory Renderer** (`Markbridge::Renderers::Discourse::Renderer`) - Renders entire AST to a string in memory.

```ruby
renderer = Markbridge::Renderers::Discourse::Renderer.new
markdown = renderer.render(ast)
```

**Note:** For very large documents (> 10 MB), consider processing in smaller chunks upstream or writing output incrementally to disk after rendering.

## Core Components

### Renderer

**Location:** `Markbridge::Renderers::Discourse::Renderer`

**Responsibility:** Orchestrate AST traversal and Markdown generation

**Key Methods:**

```ruby
# Main entry point
markdown = renderer.render(ast)

# Render children of an element
content = renderer.render_children(element, context: context)

# Access tag library
tag = renderer.tag_library[AST::Bold]
```

**Rendering Flow:**
1. Start with AST root (Document)
2. Create initial RenderContext
3. For each node:
   - If Text: Return text content
   - If Element: Look up tag, call `tag.render(element, interface)`
4. Normalize spacing in final output
5. Return Markdown string

### RenderingInterface

**Location:** `Markbridge::Renderers::Discourse::RenderingInterface`

**Responsibility:** Decouple tags from renderer implementation

**Why?**
- Tags don't depend on specific Renderer class
- Enables streaming rendering
- Simplifies testing
- Clear API contract

**Key Methods:**

```ruby
interface = RenderingInterface.new(renderer, context)

# Render child nodes
content = interface.render_children(element, context: child_context)

# Create child context
child_context = interface.with_parent(element)

# Find ancestor of specific type (O(1) cached lookup)
list = interface.find_parent(AST::List)

# Count ancestors of specific type
depth = interface.count_parents(AST::List)

# Check for ancestor
nested = interface.has_parent?(AST::List)

# Smart marker wrapping
output = interface.wrap_inline(content, "**")

# Check if element should render as block
is_block = interface.block_context?(element)
```

**Benefits:**
- **Stable API** - Tags don't break when renderer changes
- **Testable** - Easy to mock interface in tests
- **Flexible** - Support different renderer implementations

### TagLibrary

**Location:** `Markbridge::Renderers::Discourse::TagLibrary`

**Responsibility:** Map AST node classes to Tag renderers

**Key Methods:**

```ruby
library = TagLibrary.new

# Manual registration
library.register(AST::Bold, BoldTag.new)

# Auto-registration (discovers tags by naming convention)
library.auto_register!

# Lookup tag for element class
tag = library[AST::Bold]

# Use default library
library = TagLibrary.default
```

**Auto-Registration:**

Convention: `BoldTag` handles `AST::Bold`, `ItalicTag` handles `AST::Italic`, etc.

```ruby
library = TagLibrary.new
library.auto_register!

# Automatically discovers and registers:
# - BoldTag → AST::Bold
# - ItalicTag → AST::Italic
# - StrikethroughTag → AST::Strikethrough
# - UnderlineTag → AST::Underline
# - CodeTag → AST::Code
# - ListTag → AST::List
# - ListItemTag → AST::ListItem
# - UrlTag → AST::Url
# - HorizontalRuleTag → AST::HorizontalRule
```

**Benefits:**
- No manual registration needed
- Drop-in new tags inside the gem's own `Tags` namespace (just follow the naming convention)
- Reduce boilerplate

> Auto-registration walks `Markbridge::Renderers::Discourse::Tags::*` only.
> Tag classes defined in consumer code are not discovered automatically —
> register them explicitly with `library.register(MyAst, MyTag.new)`.

**Fallback Behavior:**

Unknown AST nodes use default tag that renders only children:

```ruby
library[UnknownElement] # Returns tag that renders children only
```

### RenderContext

**Location:** `Markbridge::Renderers::Discourse::RenderContext`

**Responsibility:** Track parent chain for context-aware rendering

**Key Features:**
- **Immutable** - Creates new context instead of mutating
- **Cached lookups** - O(1) parent finding via hash
- **Full ancestor chain** - Access any ancestor

**Performance:**

**Before caching (O(depth)):**
```ruby
def find_parent(klass)
  @parents.reverse.find { |p| p.is_a?(klass) }
end
# With 10 ancestors: 10 iterations
# With 50 ancestors: 50 iterations
```

**With caching (O(1)):**
```ruby
def find_parent(klass)
  @parent_cache[klass]&.last
end
# With 10 ancestors: 1 hash lookup
# With 50 ancestors: 1 hash lookup
```

**5x-10x faster** for deeply nested structures!

**Key Methods:**

```ruby
context = RenderContext.new

# Create child context (immutable)
child_context = context.with_parent(element)

# Find parent of type (O(1))
list = context.find_parent(AST::List)

# Count parents of type (O(1))
depth = context.count_parents(AST::List)

# Check for parent (O(1))
nested = context.has_parent?(AST::List)

# Access all parents
context.parents # => [Document, List, ListItem, ...]
```

**Cache Structure:**

```ruby
{
  AST::List => [list1, list2], # Multiple List ancestors
  AST::Bold => [bold1],         # One Bold ancestor
  AST::Document => [doc]        # Root document
}
```

## Rendering Tags

Tags render specific AST nodes to Markdown. Each tag implements the `render` method.

### Tag Interface

**Location:** `Markbridge::Renderers::Discourse::Tag`

**Base class for all tags:**

```ruby
class Tag
  def render(element, interface)
    raise NotImplementedError
  end
end
```

**Modern signature (November 2025):**
- `element` - AST node to render
- `interface` - RenderingInterface providing context and helpers

**Old signature (deprecated):**
- `element` - AST node
- `renderer` - Renderer instance
- `context:` - RenderContext

**Migration:**
```ruby
# Old (still works but deprecated)
class OldTag < Tag
  def render(element, renderer, context:)
    content = renderer.render_children(element, context: context.with_parent(element))
    "**#{content}**"
  end
end

# New (recommended)
class NewTag < Tag
  def render(element, interface)
    child_context = interface.with_parent(element)
    content = interface.render_children(element, context: child_context)
    interface.wrap_inline(content, "**")
  end
end
```

### Built-In Tags

#### BoldTag

**Location:** `Markbridge::Renderers::Discourse::Tags::BoldTag`

**Renders:** `AST::Bold` → `**text**`

**Implementation:**
```ruby
def render(element, interface)
  child_context = interface.with_parent(element)
  content = interface.render_children(element, context: child_context)
  interface.wrap_inline(content, "**")
end
```

**Smart wrapping:**
- If content contains `**`, falls back to `<strong>` HTML tag
- Prevents double-marking: `****text****`

**Example:**
```ruby
AST::Bold.new([AST::Text.new("Hello")])
# => "**Hello**"

AST::Bold.new([AST::Text.new("Hello**world")])
# => "<strong>Hello**world</strong>"
```

#### ItalicTag

**Location:** `Markbridge::Renderers::Discourse::Tags::ItalicTag`

**Renders:** `AST::Italic` → `*text*`

**Smart wrapping:**
- Falls back to `<em>` if content contains `*`

**Example:**
```ruby
AST::Italic.new([AST::Text.new("Hello")])
# => "*Hello*"
```

#### StrikethroughTag

**Location:** `Markbridge::Renderers::Discourse::Tags::StrikethroughTag`

**Renders:** `AST::Strikethrough` → `~~text~~`

**Smart wrapping:**
- Falls back to `<s>` if content contains `~~`

**Example:**
```ruby
AST::Strikethrough.new([AST::Text.new("Hello")])
# => "~~Hello~~"
```

#### UnderlineTag

**Location:** `Markbridge::Renderers::Discourse::Tags::UnderlineTag`

**Renders:** `AST::Underline` → `<u>text</u>`

**Note:** Always uses HTML because Discourse lacks native underline syntax.

**Example:**
```ruby
AST::Underline.new([AST::Text.new("Hello")])
# => "<u>Hello</u>"
```

#### CodeTag

**Location:** `Markbridge::Renderers::Discourse::Tags::CodeTag`

**Renders:** `AST::Code` → Inline or fenced code block

**Inline (no newlines):**
```ruby
AST::Code.new([AST::Text.new("code")])
# => "`code`"
```

**Block (contains newlines or in block context):**
```ruby
AST::Code.new(language: "ruby", children: [
  AST::Text.new("def hello\n  puts 'world'\nend")
])
# => "```ruby\ndef hello\n  puts 'world'\nend\n```"
```

**Fence selection:**
- Uses ` ``` ` by default
- Switches to `~~~` if content contains ` ``` `
- Ensures language hint included

#### ListTag

**Location:** `Markbridge::Renderers::Discourse::Tags::ListTag`

**Renders:** `AST::List` → Bulleted or numbered list

**Unordered:**
```ruby
AST::List.new(ordered: false, children: [...])
# => "\n\n- Item 1\n- Item 2\n"
```

**Ordered:**
```ruby
AST::List.new(ordered: true, children: [...])
# => "\n\n1. Item 1\n2. Item 2\n"
```

**Nested lists:**
- No extra blank lines between nested list and parent
- Indentation handled by ListItemTag

#### ListItemTag

**Location:** `Markbridge::Renderers::Discourse::Tags::ListItemTag`

**Renders:** `AST::ListItem` → List item with proper indentation

**Features:**
- Calculates nesting depth via `count_parents(AST::List)`
- Indents by 2 spaces per ancestor list
- Adds trailing newline
- Handles nested content

**Example:**
```ruby
# Top-level item
AST::ListItem.new([AST::Text.new("Item")])
# Context: count_parents(List) = 1
# => "- Item\n"

# Nested item (inside another list)
# Context: count_parents(List) = 2
# => "  - Nested\n"
```

**Builder pattern (November 2025):**
```ruby
formatter = ListItemFormatter.new(content: content, depth: depth)
  .with_marker(marker)
  .with_trailing_newline
formatted = formatter.build
```

#### UrlTag

**Location:** `Markbridge::Renderers::Discourse::Tags::UrlTag`

**Renders:** `AST::Url` → `[text](href)` or plain text

**Safe protocols:**
- `http://`, `https://`
- `ftp://`, `ftps://`
- `mailto:`

**Unsafe URLs:**
- Fall back to plain text content
- Prevents `javascript:` and other XSS vectors

**Example:**
```ruby
AST::Url.new(href: "https://example.com", children: [
  AST::Text.new("Example")
])
# => "[Example](https://example.com)"

AST::Url.new(href: "javascript:alert(1)", children: [
  AST::Text.new("Unsafe")
])
# => "Unsafe" (href dropped)
```

#### HorizontalRuleTag

**Location:** `Markbridge::Renderers::Discourse::Tags::HorizontalRuleTag`

**Renders:** `AST::HorizontalRule` → `---`

**Surrounded by blank lines:**
```ruby
AST::HorizontalRule.new
# => "\n\n---\n\n"
```

#### LineBreakTag

**Location:** Registered as block in TagLibrary

**Renders:** `AST::LineBreak` → `\n`

**Simple newline:**
```ruby
AST::LineBreak.new
# => "\n"
```

## AST to Markdown Mapping

Complete mapping of AST nodes to Discourse Markdown:

| AST Node | Markdown | HTML Fallback | Notes |
|----------|----------|---------------|-------|
| `AST::Bold` | `**text**` | `<strong>text</strong>` | Fallback when `**` in content |
| `AST::Italic` | `*text*` | `<em>text</em>` | Fallback when `*` in content |
| `AST::Strikethrough` | `~~text~~` | `<s>text</s>` | Fallback when `~~` in content |
| `AST::Underline` | `<u>text</u>` | N/A | Always HTML (no Markdown syntax) |
| `AST::Code` (inline) | `` `code` `` | N/A | No newlines in content |
| `AST::Code` (block) | ` ```lang\ncode\n``` ` | N/A | Contains newlines or block context |
| `AST::List` (unordered) | `- item` | N/A | Bullet list |
| `AST::List` (ordered) | `1. item` | N/A | Numbered list |
| `AST::ListItem` | Indented item | N/A | 2 spaces per nesting level |
| `AST::Url` | `[text](href)` | Plain text | Only safe protocols |
| `AST::LineBreak` | `\n` | N/A | Single newline |
| `AST::HorizontalRule` | `\n\n---\n\n` | N/A | Surrounded by blank lines |
| `AST::Text` | Plain text | N/A | Leaf node |
| `AST::Document` | Children only | N/A | Root node |
| Unknown element | Children only | N/A | Fallback behavior |

## Context-Aware Rendering

Tags use RenderContext to make parent-aware decisions.

### Finding Parents

```ruby
def render(element, interface)
  # Check if nested in list
  if interface.has_parent?(AST::List)
    # Render differently for list context
  end

  # Find specific parent
  list = interface.find_parent(AST::List)
  if list&.ordered?
    # Nested in ordered list
  end
end
```

### Counting Nesting Depth

```ruby
def render(element, interface)
  # Count nesting levels
  depth = interface.count_parents(AST::List)
  indent = "  " * depth

  "#{indent}- Item content"
end
```

**Used by:**
- ListItemTag for indentation
- Custom tags that need nesting awareness

### Block vs Inline Context

```ruby
def render(element, interface)
  if interface.block_context?(element)
    # Render as block with blank lines
    "\n\n#{content}\n\n"
  else
    # Render inline
    content
  end
end
```

**Block contexts:**
- Element contains newlines
- Element is `Code` or `List`, or node is `HorizontalRule`
- Can customize via `block_context?` method

### Creating Child Context

```ruby
def render(element, interface)
  # Create context with current element as parent
  child_context = interface.with_parent(element)

  # Render children with new context
  content = interface.render_children(element, context: child_context)

  # Now children can find this element as parent
  wrap(content)
end
```

**Important:**
- Always create child context before rendering children
- Enables children to find current element via `find_parent`
- Maintains proper parent chain

## Configuration

Markbridge has no global configuration. Render-side options — custom
Tags, the escaper, the postprocessor — are passed per call via a
configured `Renderer`. Build one with `Markbridge.discourse_renderer(...)`
and hand it to the convenience methods through `renderer:`:

```ruby
RENDERER =
  Markbridge.discourse_renderer(
    tags: { MyAst::Banner => MyTag::BannerTag.new },
    unregister: [Markbridge::AST::Color, Markbridge::AST::Size],
    allow: :lists,                        # MarkdownEscaper(allow:)
    escape_hard_line_breaks: true,        # MarkdownEscaper(escape_hard_line_breaks:)
    escape: false,                        # IdentityEscaper (no-op) — sugar
    escaper: MyImporter::CustomEscaper.new,         # take it wholesale
    strip_trailing_invisibles: true,      # Postprocessor(strip_trailing_invisibles:)
    postprocessor: MyImporter::CustomPostprocessor.new, # take it wholesale
  )

result = Markbridge.bbcode_to_markdown(input, renderer: RENDERER)
```

`escape:`/`escape_hard_line_breaks:`/`allow:` are sugar for building a
fresh `MarkdownEscaper` (or `IdentityEscaper` when `escape: false`).
Passing `escaper:` explicitly wins. Same precedence rule for
`strip_trailing_invisibles:` vs. `postprocessor:`. If no `renderer:`
is given to a convenience method, a fresh default `Renderer` is built
per call.

### Using Default Library

```ruby
renderer = Renderer.new
# Uses TagLibrary.default with all built-in tags
```

### Auto-Registration

```ruby
library = TagLibrary.new
library.auto_register!
# Discovers all tags in Tags module by naming convention

renderer = Renderer.new(tag_library: library)
```

### Manual Registration

```ruby
library = TagLibrary.new

# Register individual tags
library.register(AST::Bold, BoldTag.new)
library.register(AST::Italic, ItalicTag.new)

renderer = Renderer.new(tag_library: library)
```

### Custom Tags

```ruby
# Create custom tag
class QuoteTag < Tag
  def render(element, interface)
    child_context = interface.with_parent(element)
    content = interface.render_children(element, context: child_context)
    author = element.author ? " #{element.author}" : ""

    "[quote#{author}]\n#{content}\n[/quote]"
  end
end

# Register custom tag
library = TagLibrary.default
library.register(AST::Quote, QuoteTag.new)

renderer = Renderer.new(tag_library: library)
```

### Block-Based Tag Registration

```ruby
library = TagLibrary.new

# Register with block
library.register(AST::Underline) do |element, interface|
  child_context = interface.with_parent(element)
  content = interface.render_children(element, context: child_context)
  "[spoiler]#{content}[/spoiler]" # Render as spoiler instead
end

renderer = Renderer.new(tag_library: library)
```

### Custom Tag Library

```ruby
library = TagLibrary.new
library.auto_register!

# Register custom tags
library.register(AST::CustomElement, CustomTag.new)

renderer = Renderer.new(tag_library: library)
```

## Examples

### Basic Formatting

```ruby
renderer = Renderer.new

# Bold
ast = AST::Document.new([
  AST::Bold.new([AST::Text.new("Hello")])
])
renderer.render(ast) # => "**Hello**"

# Italic
ast = AST::Document.new([
  AST::Italic.new([AST::Text.new("Hello")])
])
renderer.render(ast) # => "*Hello*"

# Nested
ast = AST::Document.new([
  AST::Bold.new([
    AST::Text.new("Bold "),
    AST::Italic.new([AST::Text.new("and italic")])
  ])
])
renderer.render(ast) # => "**Bold *and italic***"
```

### Code Blocks

```ruby
# Inline code
ast = AST::Document.new([
  AST::Code.new([AST::Text.new("code")])
])
renderer.render(ast) # => "`code`"

# Block code
ast = AST::Document.new([
  AST::Code.new(
    language: "ruby",
    children: [AST::Text.new("def hello\n  puts 'world'\nend")]
  )
])
renderer.render(ast)
# => "```ruby\ndef hello\n  puts 'world'\nend\n```"
```

### Lists

```ruby
# Unordered list
list = AST::List.new(ordered: false)
list << AST::ListItem.new([AST::Text.new("First")])
list << AST::ListItem.new([AST::Text.new("Second")])

ast = AST::Document.new([list])
renderer.render(ast)
# => "\n\n- First\n- Second\n"

# Ordered list
list = AST::List.new(ordered: true)
list << AST::ListItem.new([AST::Text.new("First")])
list << AST::ListItem.new([AST::Text.new("Second")])

ast = AST::Document.new([list])
renderer.render(ast)
# => "\n\n1. First\n2. Second\n"
```

### Nested Lists

```ruby
outer = AST::List.new(ordered: false)
outer << AST::ListItem.new([AST::Text.new("Outer item")])

inner = AST::List.new(ordered: true)
inner << AST::ListItem.new([AST::Text.new("Nested 1")])
inner << AST::ListItem.new([AST::Text.new("Nested 2")])

outer << AST::ListItem.new([AST::Text.new("Item with nested list"), inner])

ast = AST::Document.new([outer])
renderer.render(ast)
# => "\n\n- Outer item\n- Item with nested list\n  1. Nested 1\n  2. Nested 2\n"
```

### Links

```ruby
ast = AST::Document.new([
  AST::Url.new(
    href: "https://example.com",
    children: [AST::Text.new("Example")]
  )
])
renderer.render(ast) # => "[Example](https://example.com)"
```

### Mixed Content

```ruby
doc = AST::Document.new
doc << AST::Bold.new([AST::Text.new("Bold")])
doc << AST::Text.new(" and ")
doc << AST::Italic.new([AST::Text.new("italic")])
doc << AST::Text.new(".")

renderer.render(doc) # => "**Bold** and *italic*."
```

### Custom Tag Example

```ruby
# Define custom AST node
class AST::Spoiler < AST::Element
end

# Define custom tag
class SpoilerTag < Tag
  def render(element, interface)
    child_context = interface.with_parent(element)
    content = interface.render_children(element, context: child_context)
    "[spoiler]#{content}[/spoiler]"
  end
end

# Register and use
library = TagLibrary.new
library.auto_register!
library.register(AST::Spoiler, SpoilerTag.new)

renderer = Renderer.new(tag_library: library)

ast = AST::Document.new([
  AST::Spoiler.new([AST::Text.new("Hidden text")])
])

renderer.render(ast) # => "[spoiler]Hidden text[/spoiler]"
```

### Large Documents

```ruby
# Build large AST
doc = AST::Document.new
10_000.times do |i|
  doc << AST::Bold.new([AST::Text.new("Item #{i}")])
  doc << AST::Text.new("\n")
end

# Render to string
renderer = Renderer.new
markdown = renderer.render(doc)

# Write to file if needed
File.write("large_output.md", markdown)
```

## Limitations

### HTML Fallbacks

Some Markdown markers fall back to HTML when content contains the marker:

```ruby
# Bold with ** in content
AST::Bold.new([AST::Text.new("a**b")])
# => "<strong>a**b</strong>" (not "**a**b**")

# Italic with * in content
AST::Italic.new([AST::Text.new("a*b")])
# => "<em>a*b</em>" (not "*a*b*")
```

**Why:** Prevents double-marking or escaping issues

### Underline Always HTML

Discourse lacks native underline syntax:

```ruby
AST::Underline.new([AST::Text.new("text")])
# => "<u>text</u>" (always HTML, no Markdown option)
```

### URL Protocol Restriction

Only safe protocols rendered as links:

```ruby
# Safe
AST::Url.new(href: "https://example.com", children: [...])
# => "[text](https://example.com)"

# Unsafe
AST::Url.new(href: "javascript:alert(1)", children: [AST::Text.new("text")])
# => "text" (href dropped for safety)
```

### Block Context Detection

Code blocks only render as blocks when:
- Content contains newlines, OR
- In block context (custom logic)

```ruby
# Inline (no newlines)
AST::Code.new([AST::Text.new("code")])
# => "`code`"

# Block (has newlines)
AST::Code.new([AST::Text.new("line1\nline2")])
# => "```\nline1\nline2\n```"
```

### Unknown AST Nodes

Unknown nodes render children only:

```ruby
class AST::Unknown < AST::Element
end

doc = AST::Document.new([
  AST::Unknown.new([AST::Text.new("content")])
])

renderer.render(doc) # => "content" (Unknown wrapper ignored)
```

## Next Steps

- **[BBCode Parser Guide](../parsers/bbcode.md)** - Learn how to build AST from BBCode
- **[Extending Markbridge](../extending.md)** - Add custom tags and renderers
- **[Architecture Overview](../architecture.md)** - Understand the full pipeline
- **[Performance Guide](../performance.md)** - Optimization tips
