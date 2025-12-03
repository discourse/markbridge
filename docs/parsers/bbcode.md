# BBCode Parser Guide

This comprehensive guide explains how the BBCode parser converts forum-style markup into the Markbridge AST, including handlers, closing strategies, limits, and error handling.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Supported Tags](#supported-tags)
- [Parser Components](#parser-components)
- [Handlers](#handlers)
- [Closing Strategies](#closing-strategies)
- [Auto-Close Behavior](#auto-close-behavior)
- [Nesting and Limits](#nesting-and-limits)
- [Error Handling](#error-handling)
- [Configuration](#configuration)
- [Examples](#examples)

## Overview

The BBCode parser (`Markbridge::Parsers::BBCode::Parser`) tokenizes input, dispatches to tag handlers, and builds an `AST::Document` tree. It follows a two-step process:

1. **Scanning** - Convert input string to tokens (text, tag start, tag end)
2. **Parsing** - Process tokens through handlers to build AST

**Key Features:**
- Graceful degradation for unknown tags (ignored while processing children)
- Configurable closing strategies (strict or reordering)
- Auto-closing of formatting tags
- Raw content handling for code blocks
- Depth limits to prevent stack overflow

## Quick Start

### Basic Usage

```ruby
require "markbridge/all"

# Simple parsing
parser = Markbridge::Parsers::BBCode::Parser.new
ast = parser.parse("[b]Hello[/b] world!")

# Check for unknown tags
parser.unknown_tags # => {}

# With custom configuration
parser = Markbridge::Parsers::BBCode::Parser.new do |registry|
  registry.closing_strategy = ClosingStrategies::Strict.new
  registry.register("custom", CustomHandler.new)
end
```

### Input Handling

The parser automatically:
- Normalizes line endings (CRLF → LF)
- Preserves whitespace and formatting
- Handles EOF without closing tags

## Supported Tags

### Formatting Tags

| Tags | Handler | AST Node | Auto-closeable | Notes |
|------|---------|----------|----------------|-------|
| `[b]`, `[bold]`, `[strong]` | `SimpleHandler` | `AST::Bold` | Yes | Nested formatting allowed |
| `[i]`, `[italic]`, `[em]` | `SimpleHandler` | `AST::Italic` | Yes | Common emphasis tag |
| `[s]`, `[strike]`, `[del]` | `SimpleHandler` | `AST::Strikethrough` | Yes | Strike-through text |
| `[u]`, `[underline]` | `SimpleHandler` | `AST::Underline` | Yes | Underline text |

### Code Tags

| Tags | Handler | AST Node | Auto-closeable | Notes |
|------|---------|----------|----------------|-------|
| `[code]`, `[pre]`, `[tt]` | `RawHandler` | `AST::Code` | No | Captures unparsed content until closing tag |

**Attributes:**
- `lang` or option attribute sets language hint
- Example: `[code lang=ruby]...[/code]` or `[code=ruby]...[/code]`

### Link Tags

| Tags | Handler | AST Node | Auto-closeable | Notes |
|------|---------|----------|----------------|-------|
| `[url]`, `[link]`, `[iurl]` | `UrlHandler` | `AST::Url` | Yes | Uses `href`, `url`, or option attribute |

**Examples:**
```bbcode
[url=https://example.com]Link text[/url]
[url href=https://example.com]Link text[/url]
[url]https://example.com[/url]
```

### List Tags

| Tags | Handler | AST Node | Auto-closeable | Notes |
|------|---------|----------|----------------|-------|
| `[list]`, `[ul]`, `[ol]`, `[ulist]`, `[olist]` | `ListHandler` | `AST::List` | No | Auto-closes open list items before closing |
| `[*]`, `[li]`, `[.]` | `ListItemHandler` | `AST::ListItem` | Yes | Auto-closes previous list item |

**Ordered Lists:**
- Use `[ol]` or `[olist]` tags
- Or `[list type=1]` / `[list=1]`

**Examples:**
```bbcode
[list]
[*]First item
[*]Second item
[/list]

[ol]
[*]Numbered item 1
[*]Numbered item 2
[/ol]
```

### Self-Closing Tags

| Tags | Handler | AST Node | Auto-closeable | Notes |
|------|---------|----------|----------------|-------|
| `[br]` | `SelfClosingHandler` | `AST::LineBreak` | N/A | Closing tag treated as text if present |
| `[hr]` | `SelfClosingHandler` | `AST::HorizontalRule` | N/A | Closing tag treated as text if present |

## Parser Components

### Scanner

**Location:** `Markbridge::Parsers::BBCode::Scanner`

**Responsibility:** Stream characters and produce tokens

**Token Types:**

#### TextToken
```ruby
token = TextToken.new("Hello world")
token.text # => "Hello world"
```

#### TagStartToken
```ruby
token = TagStartToken.new("b", {})
token.tag # => "b"
token.attrs # => {}

# With attributes
token = TagStartToken.new("url", { href: "https://example.com" })
token.attrs[:href] # => "https://example.com"
```

#### TagEndToken
```ruby
token = TagEndToken.new("b")
token.tag # => "b"
```

**Key Features:**
- Character-by-character streaming
- Minimal allocations for performance
- Automatic attribute parsing
- Position tracking for errors

### Parser

**Location:** `Markbridge::Parsers::BBCode::Parser`

**Responsibility:** Orchestrate scanning and build AST

**Key Methods:**

```ruby
# Main entry point
ast = parser.parse("[b]text[/b]")

# Access unknown tags
parser.unknown_tags # => {"unknown" => count}
```

**Parsing Flow:**
1. Normalize line endings
2. Create scanner from input
3. Wrap scanner in PeekableEnumerator for look-ahead
4. Process each token via handlers
5. Return completed AST::Document

### ParserState

**Location:** `Markbridge::Parsers::BBCode::ParserState`

**Responsibility:** Manage parsing state during traversal

**State Tracking:**
- Current node (where to add children)
- Element stack (for nested tags)
- Depth counter (prevent overflow)
- Auto-close counter (track auto-closes)

**Key Methods:**
```ruby
state.current_node # Current element being built
state.push_element(element) # Start nested element
state.pop_element # Close current element
state.depth # Current nesting depth
```

**Depth Limit:**
- Maximum depth: 100 nested elements
- Exceeding raises `MaxDepthExceededError`

### HandlerRegistry

**Location:** `Markbridge::Parsers::BBCode::HandlerRegistry`

**Responsibility:** Map tag names to handlers

**Default Registry:**
```ruby
registry = HandlerRegistry.default
# Contains all built-in handlers
```

**Custom Registry:**
```ruby
# Build from default and customize
registry = HandlerRegistry.build_from_default do |reg|
  reg.register("quote", QuoteHandler.new)
end

# Or create new registry
registry = HandlerRegistry.new
registry.register("b", SimpleHandler.new(AST::Bold, auto_closeable: true))
```

**Features:**
- Tag name normalization (case-insensitive)
- Tag name caching for performance
- Auto-closeable tracking
- Element class mapping

**Recent Improvements (November 2025):**
- `element_class` is now public (`attr_reader`)
- Simplified registration (no redundant parameters)
- Block-based configuration support
- Settable `closing_strategy` via `attr_writer`

## Handlers

Handlers convert tokens to AST nodes. Each handler type serves a specific purpose.

### BaseHandler

**Location:** `Markbridge::Parsers::BBCode::Handlers::BaseHandler`

**Base class for all handlers**

**Interface:**
```ruby
class BaseHandler
  # Public accessor to element class
  attr_reader :element_class

  # Called when opening tag encountered
  def on_open(context:, token:, registry:)
    element = create_element(token)
    context.push_element(element)
  end

  # Called when closing tag encountered
  def on_close(token:, context:, registry:, tokens: nil)
    registry.close_element(token:, context:, tokens:)
  end

  # Whether tag can be auto-closed
  def auto_closeable?
    false # Override in subclasses
  end

  private

  # Subclasses implement to create specific AST node
  def create_element(token)
    raise NotImplementedError
  end
end
```

### SimpleHandler

**Location:** `Markbridge::Parsers::BBCode::Handlers::SimpleHandler`

**Purpose:** Handle basic formatting tags (bold, italic, etc.)

**Usage:**
```ruby
# Create handler for bold tag
handler = SimpleHandler.new(AST::Bold, auto_closeable: true)

# Register with multiple tag names
registry.register(["b", "bold", "strong"], handler)
```

**Features:**
- Simple element creation
- Configurable auto-closing
- No special attribute handling

### RawHandler

**Location:** `Markbridge::Parsers::BBCode::Handlers::RawHandler`

**Purpose:** Handle code blocks that don't parse inner BBCode

**Behavior:**
1. On open tag: Start collecting raw content
2. Consume all content until matching close tag
3. Don't parse any inner BBCode
4. Create `AST::Code` with raw text

**Example:**
```bbcode
[code lang=ruby]
[b]This is not parsed as bold[/b]
puts "Raw content preserved"
[/code]
```

**Result:**
```ruby
AST::Code.new(
  language: "ruby",
  children: [AST::Text.new("[b]This is not parsed as bold[/b]\nputs \"Raw content preserved\"")]
)
```

**Attributes:**
- `lang` attribute → `language:` parameter
- Option attribute (e.g., `[code=ruby]`) → `language:` parameter

### SelfClosingHandler

**Location:** `Markbridge::Parsers::BBCode::Handlers::SelfClosingHandler`

**Purpose:** Handle tags that don't need closing (line breaks, horizontal rules)

**Behavior:**
- On open: Insert element immediately
- On close: Treat closing tags as text

**Example:**
```bbcode
Line 1[br]Line 2
[hr]
Horizontal rule above
```

**Result:**
```ruby
AST::Document.new([
  AST::Text.new("Line 1"),
  AST::LineBreak.new,
  AST::Text.new("Line 2\n"),
  AST::HorizontalRule.new,
  AST::Text.new("\nHorizontal rule above")
])
```

### UrlHandler

**Location:** `Markbridge::Parsers::BBCode::Handlers::UrlHandler`

**Purpose:** Handle link tags with URL attributes

**Attribute Resolution:**
1. Check `href` attribute
2. Check `url` attribute
3. Check option attribute (e.g., `[url=...]`)
4. If none, use child content as URL

**Examples:**
```bbcode
[url=https://example.com]Link[/url]
→ AST::Url.new(href: "https://example.com", children: [Text("Link")])

[url href=https://example.com]Link[/url]
→ AST::Url.new(href: "https://example.com", children: [Text("Link")])

[url]https://example.com[/url]
→ AST::Url.new(href: "https://example.com", children: [Text("https://example.com")])
```

### ListHandler

**Location:** `Markbridge::Parsers::BBCode::Handlers::ListHandler`

**Purpose:** Handle list containers (ordered and unordered)

**Ordered Detection:**
- Tag is `ol` or `olist`
- OR `type` attribute is "1"
- OR option attribute is "1"

**Auto-Close Behavior:**
- When closing list, auto-closes any open list item first
- Prevents malformed list structures

**Example:**
```bbcode
[list]
[*]Item 1
[*]Item 2
[/list]
```

**Result:**
```ruby
AST::List.new(ordered: false, children: [
  AST::ListItem.new(children: [AST::Text.new("Item 1")]),
  AST::ListItem.new(children: [AST::Text.new("Item 2")])
])
```

### ListItemHandler

**Location:** `Markbridge::Parsers::BBCode::Handlers::ListItemHandler`

**Purpose:** Handle list items with auto-closing

**Auto-Close Behavior:**
- When opening new list item, auto-closes previous list item
- Allows BBCode without explicit closing: `[*]Item 1 [*]Item 2`

**Example:**
```bbcode
[list]
[*]Item 1
[*]Item 2
```

Both items get auto-closed when next item starts or list closes.

## Closing Strategies

Closing strategies determine how the parser handles closing tags that don't match the current element.

### Overview

**Two strategies available:**
1. **Strict** - Auto-close only, no reordering
2. **Reordering** - Look-ahead for matching sequences (default)

**Configuration:**
```ruby
# Use strict strategy
parser = Parser.new do |registry|
  reconciler = ClosingStrategies::TagReconciler.new(registry: registry)
  registry.closing_strategy = ClosingStrategies::Strict.new(reconciler)
end

# Use reordering strategy (default)
parser = Parser.new # Already uses reordering
```

### Strict Strategy

**Location:** `Markbridge::Parsers::BBCode::ClosingStrategies::Strict`

**Three-step fallback:**
1. **Exact Match** - If closing tag matches current element, pop it
2. **Auto-Close** - Try to auto-close intermediate tags
3. **Text Fallback** - Treat closing tag as literal text

**Auto-Close Conditions (all must be met):**
- Target opening tag exists in stack (within 5 levels)
- Every element between current and target is auto-closeable
- Matching tag is less than 5 levels deep

**Example: Auto-close success**
```bbcode
[b]bold [i]italic[/b] text
```

Stack: `[root, bold, italic]`
Closing `[/b]`:
- Find bold at depth 2
- Check intermediate: italic is auto-closeable ✓
- Auto-close italic, then bold ✓

Result: `**_bold italic_** text`

**Example: Auto-close failure**
```bbcode
[b]text[i]more[/ul]
```

Stack: `[root, bold, italic]`
Closing `[/ul]`:
- No ul tag in stack ✗
- Cannot auto-close
- `[/ul]` becomes text

Result: `**text_more[/ul]_**`

### Reordering Strategy

**Location:** `Markbridge::Parsers::BBCode::ClosingStrategies::Reordering`

**Four-step fallback:**
1. **Exact Match** - Same as Strict
2. **Reordering** - Look ahead for matching closing sequence
3. **Auto-Close** - Falls back to auto-close if reordering fails
4. **Text Fallback** - Treat as literal text

**Reordering Conditions (all must be met):**
- Target opening tag exists (within 5 levels)
- Intermediate elements are auto-closeable
- Upcoming closing tags match open tags exactly

**Max peek-ahead:** 5 tokens

**Example: Reordering success**
```bbcode
[b][i]text[/b][/i]
```

Stack: `[root, bold, italic]`
Closing `[/b]`:
- Expected `[/i]`, got `[/b]`
- Peek ahead: Find `[/i]` next
- Match sequence: `[italic, bold]` == `[italic, bold]` ✓
- Consume both closers, close both properly ✓

Result: `**_text_**`

**With Strict strategy:**
- Would auto-close at `[/b]`: `**_text_**`
- Then `[/i]` becomes text: `**_text_**[/i]`

**Example: Wrong closer ahead**
```bbcode
[b][i]text[/b][u]more[/u]
```

Stack: `[root, bold, italic]`
Closing `[/b]`:
- Peek ahead: See `[u]` (tag start, not `[/i]` end)
- Reordering fails (no matching sequence) ✗
- Fall back to auto-close ✓

Result: Same as Strict

### When to Use Each Strategy

**Use Strict when:**
- You want predictable, simple behavior
- Users write well-formed BBCode
- Performance is critical (no look-ahead overhead)
- Debugging is easier (no magic reordering)

**Use Reordering when:**
- Users frequently misordering closing tags (common in forums)
- You want forgiving parsing
- Look-ahead overhead is acceptable
- Better user experience > parsing speed

### TagReconciler

**Location:** `Markbridge::Parsers::BBCode::ClosingStrategies::TagReconciler`

**Purpose:** Helper for closing strategies to match handlers

**Key Methods:**
```ruby
# Find handler for element
handler = reconciler.handler_for_element(element)

# Check if handlers match for reordering
handlers_match = reconciler.handlers_match?(handler1, handler2)
```

**Used by:**
- Reordering strategy for look-ahead matching
- Both strategies for auto-close logic

## Auto-Close Behavior

### What is Auto-Closing?

Auto-closing automatically closes intermediate tags when a closing tag doesn't match the current element.

**Example:**
```bbcode
[b][i]text[/b]
```

Stack before `[/b]`: `[root, bold, italic]`
Expected: `[/i]`
Got: `[/b]`

Auto-close:
1. Find `bold` in stack (depth 2)
2. Check `italic` is auto-closeable ✓
3. Auto-close `italic`, then close `bold` ✓

### The Auto-Close Algorithm

#### Step 1: Find the Target

Search up the stack (max 5 levels) for element matching the closing tag's handler.

```ruby
# Stack: [root, bold, italic, underline]
# Closing: [/b]
# Search: underline (no) → italic (no) → bold (yes!)
# Target: bold at depth 2
```

#### Step 2: Check Auto-Closeability

Verify that **every** element between current and target is auto-closeable.

**Auto-closeable elements:**
- Bold, Italic, Underline, Strikethrough
- Links (Url)
- Custom formatting added with `auto_closeable: true`

**Non-auto-closeable elements:**
- Lists (`[list]`, `[ul]`, `[ol]`)
- List items (`[*]`, `[li]`) - but special handling
- Code blocks (`[code]`)
- Any custom tags with `auto_closeable: false`

#### Step 3: Close the Stack

If checks pass, pop all elements from current to target (inclusive).

```ruby
# Before: [root, bold, italic, underline]
# Closing: [/b]
# Pop: underline, italic, bold
# After: [root]
# Auto-closed: 3 elements
```

### Auto-Close Limits

#### Maximum Depth: 5 Levels

Auto-closing stops at 5 levels to prevent runaway behavior.

```bbcode
[b][i][u][s][sub][sup]text[/b]
```

Stack depth to `[b]`: 6 levels
Depth limit: 5
Auto-close fails ✗
Result: `[/b]` becomes text

**Why 5?**
- Balances flexibility with performance
- Prevents deeply nested auto-close cascades
- Matches typical BBCode nesting patterns (rare to have > 5 nested format tags)
- O(5) = O(1) constant time

### Edge Cases

#### Root Document

The root Document element has no handler, so closing tags at root level always become text.

```bbcode
[/b]text
```

No bold tag open → `[/b]` becomes text
Result: `[/b]text`

#### Mixed Auto-Closeable and Block Elements

```bbcode
[b]text
[list]
[*][i]item[/b]
```

Stack: `[root, bold, list, list-item, italic]`
Closing `[/b]`:
- Find `bold` at depth 4
- Check intermediate: `list` is not auto-closeable ✗
- Cannot auto-close ✗
- `[/b]` becomes text

Result: `[/b]` rendered as text inside list item

#### Multiple Attempts

Auto-close is attempted **only once** per closing tag. If it fails, tag becomes text.

```bbcode
[b]text[list][*]item[/b][/list]
```

1. Try to auto-close at `[/b]`
2. Cannot close past `list` (not auto-closeable)
3. `[/b]` becomes text inside list item
4. No retry

### Performance Characteristics

- **Best case:** O(1) - exact match (no searching)
- **Auto-close:** O(n) where n ≤ 5 - linear scan up stack
- **Failure:** O(n) - scan completes, tag becomes text

Auto-closing adds minimal overhead due to the depth limit.

## Nesting and Limits

### Maximum Depth: 100 Elements

The parser refuses to descend beyond 100 nested elements to prevent stack overflow.

**Example:**
```ruby
bbcode = "[b]" * 101 + "text" + "[/b]" * 101
parser.parse(bbcode) # Raises MaxDepthExceededError
```

**Why 100?**
- Prevents malicious deeply-nested input from crashing
- Realistic BBCode rarely exceeds 10-20 levels
- Provides clear error message

**Error:**
```ruby
Markbridge::Parsers::BBCode::MaxDepthExceededError:
  Maximum nesting depth (100) exceeded
```

### Maximum Auto-Close Depth: 5 Levels

Auto-closing and reordering only examine the 5 most recent elements.

**Tags deeper than this limit:**
- Will not be auto-closed
- Their stray closers emitted as text
- Must be explicitly closed in order

**Example:**
```bbcode
[1][2][3][4][5][6]text[/1]
```

Stack depth to `[1]`: 6 levels
Auto-close limit: 5
Cannot auto-close `[1]` ✗
`[/1]` becomes text

### Maximum Peek-Ahead: 5 Tokens

Reordering strategy only looks ahead 5 tokens for matching sequences.

**Why 5?**
- Balances flexibility with performance
- Prevents expensive look-ahead scans
- Most misordering is within 2-3 tags

**Beyond limit:**
- Reordering won't match the sequence
- Falls back to auto-close or text

## Error Handling

### Unknown Tags

Unknown tags are tracked and ignored while their children are still parsed.

**Example:**
```ruby
parser = Parser.new
ast = parser.parse("[unknown]text[/unknown]")

# Check unknown tags
parser.unknown_tags # => {"unknown" => 2}

# AST contains only the child content
ast.children.first.text # => "text"
```

**Multiple occurrences:**
```ruby
ast = parser.parse("[foo]a[/foo] [foo]b[/foo]")
parser.unknown_tags # => {"foo" => 2}
```

### Unclosed Tags

Unclosed tags remain open until end of document.

**Example:**
```bbcode
[b]This is bold to EOF
```

Result: Bold element containing "This is bold to EOF"

### Unexpected Closing Tags

Handled by closing strategy:
- Try exact match
- Try reordering (if reordering strategy)
- Try auto-close
- Fallback to text

**Example:**
```bbcode
[b]text[/i]
```

No italic open → Cannot match → Cannot auto-close → Text
Result: `**text[/i]**`

### Raw Content EOF

If raw handler (code block) doesn't find closing tag, returns content to EOF.

**Example:**
```bbcode
[code]
No closing tag
```

Result: Code element containing "\nNo closing tag\n"

### Self-Closing Unexpected Close

Self-closing tags ignore unexpected closing tags (treat as text).

**Example:**
```bbcode
[br][/br]
```

Scanner sees:
1. `[br]` → Insert LineBreak
2. `[/br]` → No handler for close (self-closing) → Text

Result: LineBreak + Text("[/br]")

## Configuration

### Block-Based Configuration (Recommended)

```ruby
parser = Markbridge::Parsers::BBCode::Parser.new do |registry|
  # Add custom handlers
  registry.register("quote", QuoteHandler.new)
  registry.register("color", ColorHandler.new)

  # Set closing strategy
  reconciler = ClosingStrategies::TagReconciler.new(registry: registry)
  registry.closing_strategy = ClosingStrategies::Strict.new(reconciler)
end
```

### Using build_from_default

```ruby
# Start with default handlers and customize
registry = HandlerRegistry.build_from_default do |reg|
  reg.register("custom", CustomHandler.new)
end

parser = Parser.new(handlers: registry)
```

### Custom Handler Registry

```ruby
# Create from scratch
registry = HandlerRegistry.new

# Add handlers
registry.register(["b", "bold"], SimpleHandler.new(AST::Bold, auto_closeable: true))
registry.register("code", RawHandler.new)

# Set closing strategy
reconciler = ClosingStrategies::TagReconciler.new(registry: registry)
registry.closing_strategy = ClosingStrategies::Reordering.new(reconciler)

parser = Parser.new(handlers: registry)
```

## Examples

### Basic Formatting

```ruby
parser = Parser.new
ast = parser.parse("[b]Bold [i]and italic[/i][/b]")

# AST structure:
# Document
#   └─ Bold
#       ├─ Text("Bold ")
#       ├─ Italic
#       │   └─ Text("and italic")
```

### Nested Lists

```ruby
ast = parser.parse(<<~BBCODE)
  [list]
  [*]First item
  [*]Second item
    [list]
    [*]Nested item
    [/list]
  [*]Third item
  [/list]
BBCODE

# AST structure:
# Document
#   └─ List(ordered: false)
#       ├─ ListItem
#       │   └─ Text("First item")
#       ├─ ListItem
#       │   ├─ Text("Second item\n")
#       │   └─ List(ordered: false)
#       │       └─ ListItem
#       │           └─ Text("Nested item")
#       └─ ListItem
#           └─ Text("Third item")
```

### Code Blocks

```ruby
ast = parser.parse(<<~BBCODE)
  [code lang=ruby]
  def hello
    puts "world"
  end
  [/code]
BBCODE

# AST structure:
# Document
#   └─ Code(language: "ruby")
#       └─ Text("def hello\n  puts \"world\"\nend\n")
```

### Links

```ruby
ast = parser.parse("[url=https://example.com]Example[/url]")

# AST structure:
# Document
#   └─ Url(href: "https://example.com")
#       └─ Text("Example")
```

### Mixed Content

```ruby
ast = parser.parse(<<~BBCODE)
  [b]Bold text[/b] and [url=https://example.com]a link[/url].

  [list]
  [*]First
  [*]Second
  [/list]

  [code]
  Some code
  [/code]
BBCODE

# Multiple top-level elements under Document
```

### Unknown Tags

```ruby
parser = Parser.new
ast = parser.parse("[unknown]text[/unknown] [b]bold[/b]")

parser.unknown_tags # => {"unknown" => 2}

# AST structure:
# Document
#   ├─ Text("text ")
#   └─ Bold
#       └─ Text("bold")
```

### Misordered Tags (Reordering)

```ruby
ast = parser.parse("[b][i]text[/b][/i]")

# Reordering strategy:
# - Peeks ahead, sees [/i]
# - Matches sequence: [italic, bold]
# - Closes both properly

# AST structure:
# Document
#   └─ Bold
#       └─ Italic
#           └─ Text("text")
```

### Misordered Tags (Strict)

```ruby
registry = HandlerRegistry.build_from_default do |reg|
  reconciler = ClosingStrategies::TagReconciler.new(registry: reg)
  reg.closing_strategy = ClosingStrategies::Strict.new(reconciler)
end
parser = Parser.new(handlers: registry)

ast = parser.parse("[b][i]text[/b][/i]")

# Strict strategy:
# - Auto-closes at [/b]
# - [/i] becomes text

# AST structure:
# Document
#   ├─ Bold
#   │   └─ Italic
#   │       └─ Text("text")
#   └─ Text("[/i]")
```

## Next Steps

- **[Discourse Renderer Guide](../renderers/discourse.md)** - Learn how to render AST to Markdown
- **[Extending Markbridge](../extending.md)** - Add custom tags and handlers
- **[Architecture Overview](../architecture.md)** - Understand the full pipeline
